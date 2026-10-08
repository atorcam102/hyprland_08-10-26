import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick

// Window Pet: a scarf-wearing pixel penguin that lives on top of your Hyprland windows.
// It follows the real window layout (polled from hyprctl): walks along exposed window tops,
// jumps across gaps, drops down through them when there is nothing to jump to, and climbs
// window sides to get back up. Run: qs -n -p ~/.local/share/window-pet
ShellRoot {
    id: root

    // ---- tunables -------------------------------------------------------
    readonly property real sc: 2               // screen px per sprite pixel (sprite is 32x32)
    readonly property real walkSpeed: 75
    readonly property real runSpeed: 170
    readonly property real gravity: 1900
    readonly property real terminalV: 560
    readonly property real maxJumpX: 330
    readonly property real maxJumpUp: 260
    readonly property real climbSpeed: 120

    // ---- world (refreshed from hyprctl) ---------------------------------
    property string monName: ""
    property real monW: 1920
    property real monH: 1080
    property real floorY: 1000
    property var segs: []
    property bool petHidden: false

    // ---- pet state ------------------------------------------------------
    property real px: 400
    property real py: 0
    property real vx: 0
    property real vy: 0
    property int dir: 1
    property string state: "fall"    // walk idle crouch jump fall land climb
    property string idleKind: "look" // look wave sleep
    property real stateT: 0
    property real tsec: 0
    property real nextDecision: 2
    property real idleDur: 2
    property real runUntil: 0
    property bool running: false
    property var goalX: null
    property var climbT: null
    property var pend: null
    property real jx0: 0
    property real jy0: 0
    property real jx1: 0
    property real jy1: 0
    property real jdur: 1
    property real japex: 60
    property real sqx: 1
    property real sqy: 1
    property real dustT: -1
    property real dustX: 0
    property real dustY: 0
    property int animTick: 0

    // ---- "interest" mode: after a long time on the same window the pet gets curious ----
    readonly property real interestAfter: Number(Quickshell.env("PET_INTEREST_AFTER") || 180)   // seconds on one window
    property string focusAddr: ""     // the window the pet is curious about: the one whose title has stayed the same longest
    property var winTitle: ({})
    property var winSince: ({})
    property real focusSince: 0
    property real lastInterest: -1e9
    property string goalNext: "climb"    // what to do when goalX is reached: climb | peek | sit | watch
    property string interestAddr: ""
    property real holdY: 0

    // ================= world =================
    function parse(text) {
        const parts = text.split("@@")
        let clients = [], mons = []
        try { clients = JSON.parse(parts[0]); mons = JSON.parse(parts[1]) } catch (e) { return }

        const mon = mons.find(m => m.id === 0) || mons[0]
        if (!mon) return
        monName = mon.name
        monW = mon.width / mon.scale
        monH = mon.height / mon.scale
        const res = mon.reserved || [0, 0, 0, 0]
        floorY = monH - res[3]
        const ws = mon.activeWorkspace.id
        const rects = clients
            .filter(c => c.mapped && !c.hidden && c.workspace.id === ws && c.monitor === mon.id)
            .map(c => ({ x: c.at[0] - mon.x, y: c.at[1] - mon.y, w: c.size[0], h: c.size[1], fs: c.fullscreen, addr: c.address, title: c.title }))
        petHidden = rects.some(r => r.fs > 0)
        let out = []
        for (const r of rects) {
            let free = [[r.x, r.x + r.w]]
            for (const o of rects) {
                if (o === r || !(o.y < r.y - 1 && o.y + o.h > r.y - 30)) continue   // 30px: a window right above (across the tile gap) hides this top edge
                const a = o.x, b = o.x + o.w
                let next = []
                for (const f of free) {
                    if (b <= f[0] || a >= f[1]) { next.push(f); continue }
                    if (a > f[0]) next.push([f[0], a])
                    if (b < f[1]) next.push([b, f[1]])
                }
                free = next
            }
            for (const f of free)
                if (f[1] - f[0] > 60 && r.y > 20) out.push({ x0: f[0], x1: f[1], y: r.y, addr: r.addr })
        }
        out.push({ x0: 0, x1: monW, y: floorY })
        segs = out

        // A window "stays the same" while its title (e.g. the open Chrome tab) doesn't change.
        // The one that has stayed the same the longest, and has a visible top edge, gets the pet's attention.
        let t = {}, sn = {}
        for (const r of rects) {
            t[r.addr] = r.title
            sn[r.addr] = (winTitle[r.addr] === r.title && winSince[r.addr] !== undefined) ? winSince[r.addr] : tsec
        }
        winTitle = t; winSince = sn
        let best = "", bs = tsec
        for (const sg of out)
            if (sg.addr && sn[sg.addr] !== undefined && sn[sg.addr] < bs) { bs = sn[sg.addr]; best = sg.addr }
        if (best !== focusAddr) focusAddr = best
        focusSince = best ? bs : tsec
    }

    function support(x, y, tol) {
        let best = null
        for (const s of segs)
            if (x >= s.x0 && x <= s.x1 && Math.abs(s.y - y) <= tol && (!best || Math.abs(s.y - y) < Math.abs(best.y - y)))
                best = s
        return best
    }

    // ================= behaviour =================
    function setState(s) { state = s; stateT = 0 }
    function clamp(v, a, b) { return Math.max(a, Math.min(b, v)) }

    function beginJump(tx, ty) {
        jx0 = px; jy0 = py; jx1 = tx; jy1 = ty
        const dx = Math.abs(tx - px), rise = Math.max(0, py - ty)
        jdur = 0.5 + dx / 700 + rise / 1000
        japex = 55 + rise * 0.5 + dx * 0.06
        dir = tx >= px ? 1 : -1
        setState("jump")
    }
    function startJump(tx, ty) { pend = { tx: tx, ty: ty }; setState("crouch") }

    // reachable platforms. aheadOnly: only ones across a gap in the walking direction
    function jumpCands(cur, aheadOnly, only) {
        let c = []
        for (const s of segs) {
            if (s === cur || s.x1 - s.x0 < 50) continue
            if (only && s.addr !== only) continue
            let tx
            if (aheadOnly) {
                if (dir > 0 && s.x0 > px - 4) tx = s.x0 + 22
                else if (dir < 0 && s.x1 < px + 4) tx = s.x1 - 22
                else continue
            } else tx = clamp(px, s.x0 + 22, s.x1 - 22)
            const dx = Math.abs(tx - px), rise = py - s.y
            if (dx > maxJumpX || rise > maxJumpUp || rise < -320) continue
            if (dx < 20 && Math.abs(rise) < 12) continue
            c.push({ tx: tx, ty: s.y })
        }
        return c
    }
    function tryJump(cur, aheadOnly, only) {
        const c = jumpCands(cur, aheadOnly, only)
        if (c.length === 0) return false
        const k = c[Math.floor(Math.random() * c.length)]
        startJump(k.tx, k.ty)
        return true
    }

    // walk to the side of a higher window and climb up it
    function tryClimb(cur, only) {
        let best = null, bd = 1e9
        for (const t of segs) {
            if (t === cur || t.y > py - 15) continue
            if (only && t.addr !== only) continue
            for (const side of [0, 1]) {
                const wx = side === 0 ? t.x0 - 16 : t.x1 + 16
                if (wx < cur.x0 + 10 || wx > cur.x1 - 10 || wx < 14 || wx > monW - 14) continue
                const d = Math.abs(wx - px)
                if (d < bd) { bd = d; best = { t: t, side: side, wx: wx } }
            }
        }
        if (!best) return false
        goalX = best.wx; climbT = best; goalNext = "climb"
        running = true; runUntil = tsec + 6
        return true
    }

    function interested() { return focusAddr !== "" && tsec - focusSince > interestAfter && tsec - lastInterest > 25 }
    function focusedSeg() {
        let best = null
        for (const s of segs) if (s.addr === focusAddr && (!best || s.x1 - s.x0 > best.x1 - best.x0)) best = s
        return best
    }
    // walk to a spot on the focused window's top and do something curious there
    function startInterest(F) {
        const r = Math.random()
        const kind = r < 0.4 ? "peek" : (r < 0.7 ? "sit" : "watch")
        const w = F.x1 - F.x0
        let gx
        if (kind === "sit") gx = (px > (F.x0 + F.x1) / 2) ? F.x1 - 22 : F.x0 + 22          // a corner
        else if (kind === "peek") gx = F.x0 + w * (0.2 + Math.random() * 0.6)
        else gx = F.x0 + w * (0.35 + Math.random() * 0.3)
        goalX = gx; goalNext = kind; running = false
    }
    function enterInterest(kind) {
        interestAddr = focusAddr
        const s = support(px, py, 45)
        if (!s) { setState("fall"); return }
        holdY = s.y
        if (kind === "sit") dir = px > (s.x0 + s.x1) / 2 ? -1 : 1     // look towards the window
        idleDur = kind === "peek" ? 8 + Math.random() * 7 : (kind === "sit" ? 14 + Math.random() * 20 : 9 + Math.random() * 10)
        setState(kind === "peek" ? "hang" : kind)
    }
    function endInterest() {
        lastInterest = tsec
        py = holdY
        setState("walk"); nextDecision = 1 + Math.random() * 2
    }

    function edgeDecision(s) {
        if (Math.random() < 0.9 && tryJump(s, true)) return
        if (s.y < floorY - 20 && Math.random() < 0.8) {      // nothing to jump to: drop down through the gap
            px += dir * 8; vx = dir * 50; vy = 0; setState("fall"); return
        }
        dir = -dir
    }

    function decide(s) {
        nextDecision = stateT + 1 + Math.random() * 2.2
        if (goalX !== null) return
        if (interested()) {
            const F = focusedSeg()
            if (F) {
                if (s.addr === focusAddr) { startInterest(F); return }
                if (Math.random() < 0.8 && (tryJump(s, false, focusAddr) || tryClimb(s, focusAddr))) return
            }
        }
        const onFloor = s.y >= floorY - 5
        const r = Math.random()
        if (onFloor && r < 0.45 && tryClimb(s)) return
        if (r < 0.12) { idleKind = "look"; idleDur = 1.6; setState("idle") }
        else if (r < 0.19) { idleKind = "wave"; idleDur = 2.0; setState("idle") }
        else if (r < 0.23) { idleKind = "sleep"; idleDur = 4 + Math.random() * 3; setState("idle") }
        else if (r < 0.38) { running = true; runUntil = tsec + 1.5 + Math.random() * 1.5 }
        else if (r < 0.48) startJump(clamp(px + dir * 50, s.x0 + 10, s.x1 - 10), s.y)   // little hop
        else if (r < 0.70) { if (!tryJump(s, false)) dir = -dir }
        else if (r < 0.80) { if (!tryClimb(s)) dir = -dir }
        else dir = -dir
    }

    function land(hard) {
        if (hard) { dustX = px; dustY = py; dustT = 0; setState("land") }
        else setState("walk")
        nextDecision = 0.6 + Math.random() * 1.5
    }

    function tick(dt) {
        tsec += dt; stateT += dt
        if (running && tsec > runUntil) running = false
        if (dustT >= 0) { dustT += dt; if (dustT > 0.5) dustT = -1 }
        if (state === "walk" || state === "idle") {
            const s = support(px, py, 45)
            if (!s) { vx = dir * 40; vy = 0; setState("fall"); return }
            py = s.y
            if (state === "idle") {
                if (idleKind === "look" && stateT > 0.8 && stateT < 0.85) dir = -dir
                if (stateT > idleDur) { setState("walk"); nextDecision = 0.8 + Math.random() * 1.5 }
                return
            }
            const sp = running ? runSpeed : walkSpeed
            if (goalX !== null) {
                dir = goalX > px ? 1 : -1
                if (Math.abs(goalX - px) < sp * dt + 2) {
                    px = goalX; goalX = null
                    if (goalNext !== "climb") { enterInterest(goalNext); return }
                    dir = climbT.side === 0 ? 1 : -1
                    setState("climb"); return
                }
            }
            const nx = px + dir * sp * dt
            if (nx < s.x0 || nx > s.x1) {
                if (goalX !== null) { goalX = null; return }
                edgeDecision(s); return
            }
            px = nx
            if (stateT > nextDecision) decide(s)
        } else if (state === "hang" || state === "sit" || state === "watch") {
            const s = support(px, holdY, 40)
            if (!s || focusAddr !== interestAddr) { if (state === "hang") py = holdY; vx = 0; vy = 0; setState(s ? "walk" : "fall"); lastInterest = tsec; return }
            holdY = s.y
            const drop = 24 * sc
            if (state === "hang") {
                const e = (u) => u * u * (3 - 2 * u)
                if (stateT < 0.4) py = holdY + drop * e(stateT / 0.4)
                else if (stateT > idleDur - 0.5) py = holdY + drop * (1 - e(Math.min(1, (stateT - (idleDur - 0.5)) / 0.5)))
                else py = holdY + drop
            } else py = holdY
            if (stateT > idleDur) endInterest()
        } else if (state === "crouch") {
            if (stateT > 0.17 && pend) { const p = pend; pend = null; beginJump(p.tx, p.ty) }
            else if (!pend) setState("walk")
        } else if (state === "jump") {
            const t = Math.min(1, stateT / jdur)
            px = jx0 + (jx1 - jx0) * t
            py = jy0 + (jy1 - jy0) * t - 4 * japex * t * (1 - t)
            if (t >= 1) { px = jx1; py = jy1; land(Math.abs(jy1 - jy0) > 6 || Math.abs(jx1 - jx0) > 60) }
        } else if (state === "land") {
            if (stateT > 0.22) setState("walk")
        } else if (state === "climb") {
            py -= climbSpeed * dt
            const T = climbT.t
            if (stateT > 14) { vx = 0; vy = 0; setState("fall"); return }
            if (py <= T.y + 16) {
                const hx = climbT.side === 0 ? T.x0 + 26 : T.x1 - 26
                py = Math.max(py, T.y)
                beginJump(clamp(hx, T.x0 + 20, T.x1 - 20), T.y)
            }
        } else if (state === "fall") {
            vy = Math.min(terminalV, vy + gravity * dt)
            const ny = py + vy * dt
            px = clamp(px + vx * dt, 12, monW - 12)
            let hit = null
            for (const s of segs)
                if (px >= s.x0 && px <= s.x1 && s.y >= py - 1 && s.y <= ny && (!hit || s.y < hit.y)) hit = s
            if (hit) { py = hit.y; land(vy > 250); vy = 0 }
            else if (ny >= floorY) { py = floorY; land(vy > 250); vy = 0 }
            else py = ny
        }
        // squash & stretch
        let tx = 1, ty = 1
        if (state === "crouch") { tx = 1.15; ty = 0.78 }
        else if (state === "jump") { tx = 0.9; ty = 1.14 }
        else if (state === "fall") { tx = 0.94; ty = 1.06 }
        else if (state === "land") { const k = Math.max(0, 1 - stateT / 0.22); tx = 1 + 0.2 * k; ty = 1 - 0.22 * k }
        else if (state === "idle" && idleKind === "sleep") { tx = 1.06; ty = 0.94 }
        else if (state === "sit") { tx = 1.04; ty = 0.94 }
        const k2 = Math.min(1, dt * 20)
        sqx += (tx - sqx) * k2; sqy += (ty - sqy) * k2
    }

    Process {
        id: poll
        command: ["sh", "-c", "hyprctl -j clients; echo '@@'; hyprctl -j monitors"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Timer {
        interval: 400; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }
    Timer {
        interval: 16; running: true; repeat: true
        property real last: 0
        onTriggered: {
            const now = Date.now()
            const dt = last === 0 ? 0.016 : Math.min(0.05, (now - last) / 1000)
            last = now
            root.tick(dt)
        }
    }
    Timer { interval: 66; running: !root.petHidden; repeat: true; onTriggered: root.animTick = root.animTick + 1 }

    // ================= window + sprite =================
    PanelWindow {
        screen: Quickshell.screens.find(s => s.name === root.monName) ?? Quickshell.screens[0]
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "window-pet"
        color: "transparent"
        mask: Region {}

        // landing dust
        Repeater {
            model: 6
            Rectangle {
                visible: root.dustT >= 0 && !root.petHidden
                readonly property real side: index < 3 ? -1 : 1
                readonly property real n: (index % 3) + 1
                width: Math.max(1, 6 - root.dustT * 6); height: width; radius: 1
                color: "#ede0d4"
                opacity: Math.max(0, 1 - root.dustT / 0.5) * 0.85
                x: root.dustX + side * (14 + n * 10 * (0.4 + root.dustT * 3)) - width / 2
                y: root.dustY - 4 - n * 3 * root.dustT * 8 - height
            }
        }
        // sleeping z's
        Repeater {
            model: 3
            Text {
                visible: root.state === "idle" && root.idleKind === "sleep" && !root.petHidden
                text: index === 2 ? "Z" : "z"
                color: "#f5bc6f"
                font.bold: true
                font.pixelSize: 14 + index * 5
                readonly property real ph: ((root.tsec * 0.7 + index / 3) % 1)
                x: root.px + root.dir * (18 + ph * 26 + index * 4)
                y: root.py - 100 - ph * 34
                opacity: 1 - ph
            }
        }

        Canvas {
            id: pet
            visible: !root.petHidden
            width: 32
            height: 32
            smooth: false
            antialiasing: false
            x: root.px - 16
            y: root.py - 32
            transform: Scale {
                origin.x: 16
                origin.y: 32
                xScale: root.sc * root.dir * root.sqx
                yScale: root.sc * root.sqy
            }
            Connections {
                target: root
                function onAnimTickChanged() { pet.requestPaint() }
            }

            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, 32, 32)
                const W = 32
                const buf = new Array(W * W).fill(null)
                const T = root.tsec, st = root.state
                const run = root.running
                // ---- pose ----
                const ph = T * (run ? 17 : 10.5)
                let bob = 0, aF = 0.25, aB = -0.25, liftF = 0, liftB = 0, eyes = "open", beak = 0, lean = 0
                let tail = 0
                if (st === "walk") {
                    const w = Math.sin(ph)
                    bob = -Math.abs(Math.sin(ph)) * (run ? 1.6 : 1.1)
                    aF = 0.35 + 0.6 * w; aB = 0.35 - 0.6 * w
                    if (run) { aF += 0.5; aB += 0.5; lean = 1 }
                    liftF = Math.max(0, w) * 2.6; liftB = Math.max(0, -w) * 2.6
                    tail = run ? 2.5 : 1
                } else if (st === "idle") {
                    bob = Math.sin(T * 3) * 0.35
                    aF = 0.15; aB = -0.15
                    if (root.idleKind === "wave") { aF = 2.5 + Math.sin(T * 13) * 0.45; eyes = "closed" }
                    if (root.idleKind === "sleep") { eyes = "closed"; bob = 1.6 + Math.sin(T * 1.6) * 0.5; aF = 0.05; aB = -0.05 }
                } else if (st === "crouch") { bob = 2; aF = -0.4; aB = 0.4 }
                else if (st === "land") { bob = 1; aF = 1.2; aB = -1.2 }
                else if (st === "jump") { aF = 2.7; aB = 2.4; liftF = 3; liftB = 3; tail = 3 }
                else if (st === "fall") { const f = Math.sin(T * 30); aF = 2.4 + f * 0.5; aB = 2.4 - f * 0.5; liftF = 3; liftB = 3; eyes = "wide"; beak = 1; tail = 3 }
                else if (st === "climb") { const c = Math.sin(T * 9); aF = 2.4 + c * 0.6; aB = 2.4 - c * 0.6; liftF = c > 0 ? 2 : 0; liftB = c > 0 ? 0 : 2; bob = -Math.abs(c) * 0.6; lean = 1 }
                let lookX = 0, lookY = 0, bino = false
                if (st === "sit") {      // sits and studies the window below, swaying a little
                    bob = 2.4 + Math.sin(T * 1.4) * 0.3; lean = 1.4; aF = 0.5 + Math.sin(T * 1.1) * 0.1; aB = -0.3
                    liftF = 0.5; liftB = 0.5
                    lookX = Math.sin(T * 0.9); lookY = 1
                    if ((T % 7) < 0.5) eyes = "wide"
                } else if (st === "watch") {    // binoculars, scanning left and right
                    bob = Math.sin(T * 2) * 0.4; lean = 1.6; aF = 2.3; aB = -0.2
                    lookX = Math.sin(T * 1.3); lookY = 0.6; bino = true
                } else if (st === "hang") {     // hanging from the window's edge by the flippers, feet swinging
                    aF = 3.0; aB = 2.85; bob = 0.3
                    liftF = 1.6 + Math.sin(T * 2.4) * 1.6; liftB = 1.6 + Math.sin(T * 2.4 + 1.6) * 1.6
                    lookX = Math.sin(T * 1.1); lookY = 1; lean = 0.8; tail = 2
                    if ((T % 6) < 0.5) eyes = "wide"
                }
                if (eyes === "open" && (T % 4.2) < 0.14) eyes = "closed"

                // ---- mini pixel renderer ----
                function put(x, y, c) { x = Math.round(x); y = Math.round(y); if (x >= 0 && x < W && y >= 0 && y < W) buf[y * W + x] = c }
                function ell(cx, cy, rx, ry, sh) {
                    for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++)
                        for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) {
                            const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry
                            if (dx * dx + dy * dy <= 1) { const c = typeof sh === "string" ? sh : sh(dx, dy); if (c) put(x, y, c) }
                        }
                }
                function limb(x0, y0, x1, y1, r, sh) {
                    const n = Math.ceil(Math.hypot(x1 - x0, y1 - y0) * 2) + 1
                    for (let i = 0; i < n; i++) { const t = i / Math.max(1, n - 1); ell(x0 + (x1 - x0) * t, y0 + (y1 - y0) * t, r, r, sh) }
                }
                function tone(p, lo, hi) { return (dx, dy) => { const l = -dx * 0.55 - dy * 0.65; return l > hi ? p[2] : l > lo ? p[1] : p[0] } }
                const DK = ["#2a1f14", "#3d2e1f", "#56432b"], DK2 = ["#1e160e", "#2a1f14", "#3d2e1f"]
                const BL = ["#d9c7ae", "#ede0d4", "#fff6ec"], OR = ["#c2560f", "#e07a24", "#f1a24a"], TL = ["#b9803a", "#f5bc6f", "#ffddb4"]
                const body = tone(DK, -0.15, 0.45), backfl = tone(DK2, -0.1, 0.5), belly = tone(BL, -0.3, 0.3)
                const orange = tone(OR, -0.2, 0.4), teal = tone(TL, -0.1, 0.4)

                const by = bob, hx = lean * 0.8
                function flipper(sx, sy, a, sh) { limb(sx, sy + by, sx + 9 * Math.sin(a), sy + by + 9 * Math.cos(a), 1.7, sh) }
                // back flipper + back foot + tail
                flipper(19.5, 15.5, aB, backfl)
                ell(10.5, 29.3 - liftB, 3.6, 1.6, orange)
                ell(6.5, 25 + by, 2.6, 1.6, DK2[1])
                // body + head
                ell(15, 17.6 + by, 8.2, 10.6, body)
                ell(16 + hx, 10 + by, 7.2, 6.6, body)
                // belly + face patch
                ell(17.6, 20.3 + by, 5.2, 7.6, belly)
                ell(18.6 + hx, 10.6 + by, 4.3, 3.8, belly)
                // scarf band
                ell(15.6 + hx * 0.5, 16.2 + by, 7.7, 2.1, teal)
                // scarf tail (flutters)
                const fx = Math.sin(T * 8) * 1.1, fy = Math.cos(T * 6.5) * 1.3
                limb(9, 16.8 + by, 4.5 - tail + fx, 18.5 + by - tail * 0.7 + fy, 1.3, teal)
                limb(4.5 - tail + fx, 18.5 + by - tail * 0.7 + fy, 2 - tail * 1.3 + fx, 21 + by - tail * 0.9 + fy, 1.2, TL[0])
                // eye
                const ex = 19.6 + hx, ey = 8.6 + by
                if (eyes === "closed") { put(ex - 1, ey + 1, "#140d06"); put(ex, ey + 1.2, "#140d06"); put(ex + 1, ey + 1, "#140d06") }
                else if (eyes === "wide") { ell(ex, ey + 1, 2.3, 2.6, "#ffffff"); ell(ex + 0.4, ey + 1.2, 1.1, 1.3, "#140d06") }
                else { ell(ex + lookX * 0.8, ey + 1 + lookY * 0.7, 1.3, 1.9, "#140d06"); put(ex - 0.5 + lookX * 0.8, ey + lookY * 0.7, "#ffffff") }
                if (eyes === "wide" && st !== "fall") { put(ex + 3, ey - 3, "#ffffff"); put(ex + 2, ey - 3, "#ffffff"); put(ex + 4, ey - 3, "#ffffff"); put(ex + 3, ey - 4, "#ffffff"); put(ex + 3, ey - 2, "#ffffff") }
                // beak
                ell(23.4 + hx, 11.2 + by, 2.7, 1.25, orange)
                ell(22.7 + hx, 12.9 + by + beak, 2.1, 0.9, OR[0])
                if (bino) {
                    limb(ex - 1.5, ey - 1.2, ex - 6, ey - 3.2, 0.7, "#241a10")
                    ell(ex + 3.4, ey + 1, 3.1, 3.1, "#241a10"); ell(ex + 4.4, ey + 1, 1.9, 2.1, "#ffddb4"); put(ex + 3.8, ey, "#ffffff")
                }
                // blush
                put(21.2 + hx, 12.6 + by, "#ff9db5"); put(20.2 + hx, 12.8 + by, "#ff9db5")
                // front foot
                ell(19.6, 29.3 - liftF, 3.7, 1.6, orange)
                // front flipper
                flipper(11.5, 16, aF, body)

                // ---- outline + flush ----
                const O = "#120c06"
                const out = buf.slice()
                for (let y = 0; y < W; y++) for (let x = 0; x < W; x++) {
                    if (buf[y * W + x]) continue
                    if ((x > 0 && buf[y * W + x - 1]) || (x < W - 1 && buf[y * W + x + 1]) ||
                        (y > 0 && buf[(y - 1) * W + x]) || (y < W - 1 && buf[(y + 1) * W + x])) out[y * W + x] = O
                }
                for (let y = 0; y < W; y++) for (let x = 0; x < W; x++) {
                    const c = out[y * W + x]
                    if (c) { ctx.fillStyle = c; ctx.fillRect(x, y, 1, 1) }
                }
            }
        }
    }
}
