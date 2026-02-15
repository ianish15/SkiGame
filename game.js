// ── Ski Run ── First-person endless skiing game ──

const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

// ── Responsive canvas ──
function resize() {
    canvas.width = window.innerWidth * devicePixelRatio;
    canvas.height = window.innerHeight * devicePixelRatio;
    ctx.setTransform(devicePixelRatio, 0, 0, devicePixelRatio, 0, 0);
}
window.addEventListener("resize", resize);
resize();

const W = () => window.innerWidth;
const H = () => window.innerHeight;

// ── Game states ──
const STATE = { MENU: 0, PLAYING: 1, DEAD: 2 };
let state = STATE.MENU;

// ── Player / world state ──
let playerX;       // lateral position on trail (-1 to 1, 0 = center)
let speed;         // current forward speed
let distance;      // total distance traveled
let score;
let turnDir;       // -1 left, 0 none, 1 right
let touchSide;     // for visual indicator
let alive;

// Difficulty ramps
let baseSpeed;
let trailWidth;    // half-width in world units
let obstacleRate;

// World segments and objects
let segments;      // array of road segments
let obstacles;     // spawned obstacles
let nextObstacleZ; // z of next obstacle spawn
let curvature;     // current trail curve
let curveTarget;   // target curve
let curveTimer;

// Particles
let particles;
let snowflakes;

// Timing
let lastTime = 0;
let highScore = loadHighScore();

// ── Constants ──
const SEG_LENGTH = 5;        // world-units per segment
const DRAW_DIST = 180;       // how far ahead to render
const NUM_SEGMENTS = Math.ceil(DRAW_DIST / SEG_LENGTH) + 5;
const CAMERA_HEIGHT = 4;
const CAMERA_DEPTH = 1 / Math.tan((80 / 2) * Math.PI / 180); // FOV ~80deg
const HORIZON = 0.38;        // horizon line as fraction of screen height

// ── Persistence ──
function loadHighScore() {
    try { return parseInt(localStorage.getItem("skiRunHigh")) || 0; } catch { return 0; }
}
function saveHighScore(s) {
    if (s > highScore) {
        highScore = s;
        try { localStorage.setItem("skiRunHigh", s); } catch {}
    }
}

// ── Snowflakes (ambient) ──
function initSnowflakes() {
    snowflakes = [];
    for (let i = 0; i < 80; i++) {
        snowflakes.push({
            x: Math.random() * W(),
            y: Math.random() * H(),
            r: Math.random() * 2.5 + 0.5,
            vx: Math.random() * 0.4 - 0.2,
            vy: Math.random() * 1.2 + 0.4,
            opacity: Math.random() * 0.5 + 0.2,
        });
    }
}

function updateSnowflakes(dt) {
    const w = W(), h = H();
    for (const s of snowflakes) {
        s.x += (s.vx + curvature * speed * 0.3) * dt * 60;
        s.y += s.vy * dt * 60;
        if (s.y > h) { s.y = -2; s.x = Math.random() * w; }
        if (s.x < 0) s.x = w;
        if (s.x > w) s.x = 0;
    }
}

function drawSnowflakes() {
    for (const s of snowflakes) {
        ctx.beginPath();
        ctx.arc(s.x, s.y, s.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${s.opacity})`;
        ctx.fill();
    }
}

// ── Particles (snow spray) ──
function spawnSpray(screenX, screenY, dir) {
    for (let i = 0; i < 2; i++) {
        particles.push({
            x: screenX,
            y: screenY,
            vx: (Math.random() - 0.5) * 2 + dir * 2,
            vy: -(Math.random() * 2 + 1),
            life: 0.3 + Math.random() * 0.2,
            maxLife: 0.3 + Math.random() * 0.2,
            r: Math.random() * 2.5 + 1,
        });
    }
}

function spawnCrash(screenX, screenY) {
    for (let i = 0; i < 35; i++) {
        const a = Math.random() * Math.PI * 2;
        const sp = Math.random() * 6 + 2;
        particles.push({
            x: screenX, y: screenY,
            vx: Math.cos(a) * sp,
            vy: Math.sin(a) * sp - 3,
            life: 0.6 + Math.random() * 0.5,
            maxLife: 0.6 + Math.random() * 0.5,
            r: Math.random() * 3.5 + 1,
        });
    }
}

function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.x += p.vx * dt * 60;
        p.y += p.vy * dt * 60;
        p.vy += 4 * dt * 60; // gravity
        p.life -= dt;
        if (p.life <= 0) particles.splice(i, 1);
    }
}

function drawParticles() {
    for (const p of particles) {
        const a = Math.max(0, p.life / p.maxLife);
        ctx.beginPath();
        ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${a * 0.9})`;
        ctx.fill();
    }
}

// ── Trail / road segment helpers ──
function resetSegments() {
    segments = [];
    for (let i = 0; i < NUM_SEGMENTS; i++) {
        segments.push({ curve: 0, z: i * SEG_LENGTH });
    }
}

function recycleSegments() {
    // Remove segments behind the player; add new ones ahead
    while (segments.length > 0 && segments[0].z < distance - SEG_LENGTH) {
        segments.shift();
    }
    while (segments.length < NUM_SEGMENTS) {
        const lastZ = segments.length > 0 ? segments[segments.length - 1].z : distance;
        segments.push({ curve: curvature, z: lastZ + SEG_LENGTH });
    }
}

// ── Obstacle spawning ──
function spawnObstacle(z) {
    // Pick type
    const r = Math.random();
    let type, lane;

    if (r < 0.45) {
        type = "tree";
        // Trees on edges and sometimes on trail
        const edgeBias = Math.random();
        if (edgeBias < 0.35) {
            lane = (Math.random() < 0.5 ? -1 : 1) * (0.5 + Math.random() * 0.8);
        } else {
            lane = (Math.random() - 0.5) * 1.8;
        }
    } else if (r < 0.7) {
        type = "rock";
        lane = (Math.random() - 0.5) * 1.4;
    } else if (r < 0.85) {
        type = "snowman";
        lane = (Math.random() - 0.5) * 1.2;
    } else {
        type = "gate";
        lane = (Math.random() - 0.5) * 0.8;
    }

    obstacles.push({ type, lane, z, passed: false, hitRadius: type === "gate" ? 0.35 : 0.12 });
}

// ── Project 3D point to screen ──
function project(laneX, worldZ, cameraZ, camX) {
    const w = W(), h = H();
    const relZ = worldZ - cameraZ;
    if (relZ <= 0.1) return null;

    const scale = CAMERA_DEPTH / relZ;
    const screenX = w / 2 + (laneX - camX) * scale * w * 0.5;
    const screenY = h * HORIZON - (CAMERA_HEIGHT * scale * h * 0.3);
    const screenW = scale * w * 0.5;

    return { x: screenX, y: screenY, w: screenW, scale };
}

// ── Initialize a run ──
function startRun() {
    playerX = 0;
    speed = 0;
    distance = 0;
    score = 0;
    turnDir = 0;
    touchSide = 0;
    alive = true;
    baseSpeed = 28;
    trailWidth = 1.0;
    obstacleRate = 18;
    curvature = 0;
    curveTarget = 0;
    curveTimer = 0;
    particles = [];
    obstacles = [];
    nextObstacleZ = 30;
    resetSegments();
    state = STATE.PLAYING;
}

// ── Input ──
function handleInputStart(clientX) {
    if (state === STATE.PLAYING) {
        const mid = W() / 2;
        touchSide = clientX < mid ? -1 : 1;
        turnDir = touchSide;
    }
}

function handleInputEnd() {
    turnDir = 0;
    touchSide = 0;
}

canvas.addEventListener("touchstart", (e) => {
    e.preventDefault();
    handleInputStart(e.touches[0].clientX);
    tapPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
}, { passive: false });
canvas.addEventListener("touchmove", (e) => e.preventDefault(), { passive: false });
canvas.addEventListener("touchend", (e) => {
    e.preventDefault();
    if (e.touches.length === 0) handleInputEnd();
}, { passive: false });

canvas.addEventListener("mousedown", (e) => {
    handleInputStart(e.clientX);
    tapPos = { x: e.clientX, y: e.clientY };
});
canvas.addEventListener("mouseup", handleInputEnd);

let tapPos = null;

// ── Update ──
function update(dt) {
    updateSnowflakes(dt);

    if (state !== STATE.PLAYING) return;

    // Difficulty ramp over distance
    const difficultyT = Math.min(distance / 15000, 1);
    const currentMaxSpeed = baseSpeed + difficultyT * 42; // 28 -> 70
    trailWidth = 1.0 - difficultyT * 0.45;               // 1.0 -> 0.55
    obstacleRate = 18 - difficultyT * 10;                 // 18 -> 8

    // Accelerate
    if (speed < currentMaxSpeed) {
        speed += dt * 12;
        if (speed > currentMaxSpeed) speed = currentMaxSpeed;
    }

    // Turning
    const turnRate = 1.8;
    if (turnDir !== 0) {
        playerX += turnDir * turnRate * dt;
        speed *= (1 - 0.15 * dt); // slight slowdown
    }

    // Curvature shifts player position (centrifugal effect)
    playerX += curvature * speed * dt * 0.012;

    // Trail curves — change direction periodically
    curveTimer -= dt;
    if (curveTimer <= 0) {
        curveTarget = (Math.random() - 0.5) * (1.5 + difficultyT * 2.5);
        curveTimer = 1.5 + Math.random() * 3;
    }
    curvature += (curveTarget - curvature) * dt * 1.2;

    // Move forward
    distance += speed * dt;
    score = Math.floor(distance / 3);

    // Recycle road segments
    recycleSegments();

    // Spawn obstacles
    while (nextObstacleZ < distance + DRAW_DIST) {
        spawnObstacle(nextObstacleZ);
        nextObstacleZ += obstacleRate * (0.6 + Math.random() * 0.8);
    }

    // Remove old obstacles
    for (let i = obstacles.length - 1; i >= 0; i--) {
        if (obstacles[i].z < distance - 10) obstacles.splice(i, 1);
    }

    // Collision detection
    for (const ob of obstacles) {
        const relZ = ob.z - distance;
        if (relZ > 0 && relZ < 3) {
            const dx = Math.abs(playerX - ob.lane);
            if (ob.type === "gate") {
                if (!ob.passed && dx < ob.hitRadius) {
                    ob.passed = true;
                    score += 200;
                    speed += 3;
                }
            } else {
                if (dx < ob.hitRadius) {
                    // Crash
                    alive = false;
                    state = STATE.DEAD;
                    speed = 0;
                    saveHighScore(score);
                    // Crash particles at player position
                    spawnCrash(W() / 2, H() * 0.82);
                    return;
                }
            }
        }
    }

    // Snow spray while turning
    if (turnDir !== 0 && speed > 5) {
        spawnSpray(W() / 2 - turnDir * 20, H() * 0.88, -turnDir);
    }

    updateParticles(dt);
}

// ── Draw ──
function draw() {
    const w = W(), h = H();

    if (state === STATE.MENU) {
        drawMenuScreen();
        return;
    }

    // ── Sky ──
    const skyGrad = ctx.createLinearGradient(0, 0, 0, h * HORIZON);
    skyGrad.addColorStop(0, "#6BB3D9");
    skyGrad.addColorStop(0.5, "#9DCCEA");
    skyGrad.addColorStop(1, "#D4E8F5");
    ctx.fillStyle = skyGrad;
    ctx.fillRect(0, 0, w, h * HORIZON + 1);

    // Mountains on horizon
    drawMountains(w, h);

    // ── Road / trail rendering ──
    drawRoad(w, h);

    // ── Obstacles ──
    // Sort back-to-front
    const sorted = obstacles
        .filter(ob => ob.z > distance && ob.z < distance + DRAW_DIST)
        .sort((a, b) => b.z - a.z);

    let camX = playerX;
    // Accumulate curve offset for camera
    let cumulativeCurve = 0;
    for (const seg of segments) {
        if (seg.z >= distance && seg.z < distance + DRAW_DIST * 0.3) {
            cumulativeCurve += seg.curve * 0.002;
        }
    }
    camX -= cumulativeCurve;

    for (const ob of sorted) {
        const p = project(ob.lane, ob.z, distance, camX);
        if (!p || p.y < 0 || p.y > h) continue;

        const s = p.w * 0.6; // size scaling
        if (ob.type === "tree") drawTree3D(p.x, p.y, s);
        else if (ob.type === "rock") drawRock3D(p.x, p.y, s);
        else if (ob.type === "snowman") drawSnowman3D(p.x, p.y, s);
        else if (ob.type === "gate") drawGate3D(p.x, p.y, s, ob.passed);
    }

    drawSnowflakes();
    drawParticles();

    // ── Skier (first person — skis at bottom) ──
    drawSkierPOV(w, h);

    // ── HUD ──
    drawHUD(w, h);

    // Turn indicators
    if (state === STATE.PLAYING) drawTurnHints(w, h);

    // ── Death overlay ──
    if (state === STATE.DEAD) drawDeathScreen(w, h);
}

function drawMountains(w, h) {
    const horizY = h * HORIZON;

    ctx.fillStyle = "#A0B8C8";
    ctx.beginPath();
    ctx.moveTo(0, horizY);
    ctx.lineTo(w * 0.1, horizY - 40);
    ctx.lineTo(w * 0.2, horizY - 15);
    ctx.lineTo(w * 0.35, horizY - 65);
    ctx.lineTo(w * 0.5, horizY - 25);
    ctx.lineTo(w * 0.65, horizY - 70);
    ctx.lineTo(w * 0.8, horizY - 30);
    ctx.lineTo(w * 0.9, horizY - 50);
    ctx.lineTo(w, horizY - 20);
    ctx.lineTo(w, horizY);
    ctx.closePath();
    ctx.fill();

    // Snow caps
    ctx.fillStyle = "#D8E8F0";
    ctx.beginPath();
    ctx.moveTo(w * 0.35, horizY - 65);
    ctx.lineTo(w * 0.30, horizY - 40);
    ctx.lineTo(w * 0.40, horizY - 40);
    ctx.closePath();
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(w * 0.65, horizY - 70);
    ctx.lineTo(w * 0.60, horizY - 42);
    ctx.lineTo(w * 0.70, horizY - 42);
    ctx.closePath();
    ctx.fill();
}

function drawRoad(w, h) {
    const horizY = h * HORIZON;
    const roadH = h - horizY;

    let camX = playerX;
    let cumulativeCurve = 0;

    // Render road strips from horizon down
    const strips = 120;
    for (let i = strips; i >= 0; i--) {
        const t = i / strips;                   // 0 = bottom (near), 1 = top (far)
        const screenY = horizY + roadH * (1 - t);
        const depth = 0.5 + t * DRAW_DIST;     // pseudo depth
        const perspective = 1 / (depth * 0.04 + 0.2);

        // Curvature offset at this depth
        const segIdx = Math.floor(t * (segments.length - 1));
        const seg = segments[Math.min(segIdx, segments.length - 1)];
        cumulativeCurve += (seg ? seg.curve : 0) * t * 0.3;

        const centerX = w / 2 - playerX * perspective * w * 0.5 + cumulativeCurve * perspective * 8;
        const halfTrail = trailWidth * perspective * w * 0.45;

        const stripH = roadH / strips + 1;

        // Off-piste snow
        const offPisteColor = (Math.floor(depth / 4) % 2 === 0) ? "#E4ECF2" : "#DCE6EE";
        ctx.fillStyle = offPisteColor;
        ctx.fillRect(0, screenY, w, stripH);

        // Trail surface
        const trailColor = (Math.floor(depth / 4) % 2 === 0) ? "#F4F8FC" : "#EDF2F8";
        ctx.fillStyle = trailColor;
        ctx.fillRect(centerX - halfTrail, screenY, halfTrail * 2, stripH);

        // Trail edge markers
        ctx.fillStyle = "rgba(200,60,60,0.4)";
        ctx.fillRect(centerX - halfTrail - 2, screenY, 3 * perspective + 1, stripH);
        ctx.fillRect(centerX + halfTrail - 1, screenY, 3 * perspective + 1, stripH);

        // Center dashes (periodic)
        if (Math.floor(depth / 6) % 3 === 0) {
            ctx.fillStyle = "rgba(150,180,200,0.15)";
            ctx.fillRect(centerX - 1, screenY, 2, stripH);
        }
    }
}

function drawTree3D(x, y, s) {
    const size = Math.max(s * 0.8, 2);

    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.1)";
    ctx.beginPath();
    ctx.ellipse(x + size * 0.1, y, size * 0.5, size * 0.15, 0, 0, Math.PI * 2);
    ctx.fill();

    // Trunk
    ctx.fillStyle = "#5D4037";
    ctx.fillRect(x - size * 0.06, y - size * 0.6, size * 0.12, size * 0.6);

    // Foliage
    const greens = ["#1B5E20", "#2E7D32", "#388E3C"];
    for (let i = 0; i < 3; i++) {
        ctx.fillStyle = greens[i];
        ctx.beginPath();
        const ty = y - size * (1.3 - i * 0.3);
        const bw = size * (0.35 + i * 0.05);
        ctx.moveTo(x, ty);
        ctx.lineTo(x - bw, ty + size * 0.4);
        ctx.lineTo(x + bw, ty + size * 0.4);
        ctx.closePath();
        ctx.fill();
    }

    // Snow on top
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.moveTo(x, y - size * 1.35);
    ctx.lineTo(x - size * 0.18, y - size * 1.1);
    ctx.lineTo(x + size * 0.18, y - size * 1.1);
    ctx.closePath();
    ctx.fill();
}

function drawRock3D(x, y, s) {
    const size = Math.max(s * 0.5, 2);

    ctx.fillStyle = "rgba(0,0,0,0.1)";
    ctx.beginPath();
    ctx.ellipse(x, y, size * 0.5, size * 0.15, 0, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = "#78909C";
    ctx.beginPath();
    ctx.moveTo(x - size * 0.4, y);
    ctx.lineTo(x - size * 0.2, y - size * 0.45);
    ctx.lineTo(x + size * 0.15, y - size * 0.5);
    ctx.lineTo(x + size * 0.4, y - size * 0.15);
    ctx.lineTo(x + size * 0.35, y);
    ctx.closePath();
    ctx.fill();

    ctx.fillStyle = "#E0E0E0";
    ctx.beginPath();
    ctx.moveTo(x - size * 0.15, y - size * 0.3);
    ctx.lineTo(x + size * 0.1, y - size * 0.48);
    ctx.lineTo(x + size * 0.3, y - size * 0.15);
    ctx.lineTo(x + size * 0.05, y - size * 0.15);
    ctx.closePath();
    ctx.fill();
}

function drawSnowman3D(x, y, s) {
    const size = Math.max(s * 0.6, 2);

    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.08)";
    ctx.beginPath();
    ctx.ellipse(x, y, size * 0.35, size * 0.1, 0, 0, Math.PI * 2);
    ctx.fill();

    // Bottom ball
    ctx.fillStyle = "#F0F0F0";
    ctx.beginPath();
    ctx.arc(x, y - size * 0.2, size * 0.3, 0, Math.PI * 2);
    ctx.fill();

    // Middle ball
    ctx.fillStyle = "#F5F5F5";
    ctx.beginPath();
    ctx.arc(x, y - size * 0.55, size * 0.22, 0, Math.PI * 2);
    ctx.fill();

    // Head
    ctx.fillStyle = "#FAFAFA";
    ctx.beginPath();
    ctx.arc(x, y - size * 0.82, size * 0.15, 0, Math.PI * 2);
    ctx.fill();

    // Hat
    ctx.fillStyle = "#333";
    ctx.fillRect(x - size * 0.12, y - size * 1.05, size * 0.24, size * 0.15);
    ctx.fillRect(x - size * 0.18, y - size * 0.93, size * 0.36, size * 0.04);

    // Eyes
    ctx.fillStyle = "#000";
    ctx.beginPath();
    ctx.arc(x - size * 0.05, y - size * 0.84, size * 0.02, 0, Math.PI * 2);
    ctx.arc(x + size * 0.05, y - size * 0.84, size * 0.02, 0, Math.PI * 2);
    ctx.fill();

    // Nose
    ctx.fillStyle = "#FF7043";
    ctx.beginPath();
    ctx.moveTo(x, y - size * 0.8);
    ctx.lineTo(x + size * 0.12, y - size * 0.78);
    ctx.lineTo(x, y - size * 0.76);
    ctx.closePath();
    ctx.fill();
}

function drawGate3D(x, y, s, passed) {
    const size = Math.max(s * 0.8, 2);
    const hw = size * 0.5;
    const color = passed ? "rgba(76,175,80,0.4)" : "#F44336";

    // Poles
    ctx.fillStyle = color;
    ctx.fillRect(x - hw - size * 0.03, y - size * 0.9, size * 0.06, size * 0.9);
    ctx.fillRect(x + hw - size * 0.03, y - size * 0.9, size * 0.06, size * 0.9);

    // Banner
    ctx.fillStyle = passed ? "rgba(76,175,80,0.2)" : "rgba(244,67,54,0.3)";
    ctx.fillRect(x - hw, y - size * 0.8, hw * 2, size * 0.15);

    if (!passed) {
        // Stripes
        ctx.fillStyle = "#fff";
        for (let i = 0; i < 3; i++) {
            const sy = y - size * 0.85 + i * size * 0.25;
            ctx.fillRect(x - hw - size * 0.03, sy, size * 0.06, size * 0.08);
            ctx.fillRect(x + hw - size * 0.03, sy, size * 0.06, size * 0.08);
        }
    }

    if (passed) {
        ctx.fillStyle = "rgba(76,175,80,0.8)";
        ctx.font = `bold ${Math.max(size * 0.2, 8)}px sans-serif`;
        ctx.textAlign = "center";
        ctx.fillText("+200", x, y - size * 0.95);
    }
}

function drawSkierPOV(w, h) {
    const bx = w / 2;
    const by = h * 0.92;

    // Skis
    ctx.strokeStyle = "#222";
    ctx.lineWidth = 3.5;
    ctx.lineCap = "round";

    const skiSpread = 22;
    const skiLen = 55;
    const tilt = turnDir * 0.15;

    // Left ski
    ctx.beginPath();
    ctx.moveTo(bx - skiSpread, by + 10);
    ctx.lineTo(bx - skiSpread - tilt * 20, by - skiLen);
    ctx.stroke();

    // Right ski
    ctx.beginPath();
    ctx.moveTo(bx + skiSpread, by + 10);
    ctx.lineTo(bx + skiSpread - tilt * 20, by - skiLen);
    ctx.stroke();

    // Ski tips
    ctx.lineWidth = 2.5;
    ctx.beginPath();
    ctx.moveTo(bx - skiSpread - tilt * 20, by - skiLen);
    ctx.quadraticCurveTo(bx - skiSpread - tilt * 20, by - skiLen - 10, bx - skiSpread - tilt * 20 + 4, by - skiLen - 12);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(bx + skiSpread - tilt * 20, by - skiLen);
    ctx.quadraticCurveTo(bx + skiSpread - tilt * 20, by - skiLen - 10, bx + skiSpread - tilt * 20 + 4, by - skiLen - 12);
    ctx.stroke();

    // Poles
    ctx.strokeStyle = "#555";
    ctx.lineWidth = 2;

    if (turnDir === -1) {
        // Left pole dug in
        ctx.beginPath();
        ctx.moveTo(bx - 40, by - 30);
        ctx.lineTo(bx - 80, by - skiLen - 30);
        ctx.stroke();
        // Right pole up
        ctx.beginPath();
        ctx.moveTo(bx + 40, by - 30);
        ctx.lineTo(bx + 55, by - skiLen - 10);
        ctx.stroke();
    } else if (turnDir === 1) {
        // Right pole dug in
        ctx.beginPath();
        ctx.moveTo(bx + 40, by - 30);
        ctx.lineTo(bx + 80, by - skiLen - 30);
        ctx.stroke();
        // Left pole up
        ctx.beginPath();
        ctx.moveTo(bx - 40, by - 30);
        ctx.lineTo(bx - 55, by - skiLen - 10);
        ctx.stroke();
    } else {
        // Both poles neutral
        ctx.beginPath();
        ctx.moveTo(bx - 40, by - 25);
        ctx.lineTo(bx - 50, by - skiLen - 5);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(bx + 40, by - 25);
        ctx.lineTo(bx + 50, by - skiLen - 5);
        ctx.stroke();
    }

    // Pole baskets (small circles at bottom)
    ctx.fillStyle = "#666";
    if (turnDir === -1) {
        ctx.beginPath(); ctx.arc(bx - 80, by - skiLen - 30, 3, 0, Math.PI * 2); ctx.fill();
    } else if (turnDir === 1) {
        ctx.beginPath(); ctx.arc(bx + 80, by - skiLen - 30, 3, 0, Math.PI * 2); ctx.fill();
    }

    // Gloves / hands (two colored ovals at the bottom corners)
    ctx.fillStyle = "#D32F2F";
    ctx.beginPath();
    ctx.ellipse(bx - 40, by - 25, 7, 5, -0.3, 0, Math.PI * 2);
    ctx.fill();
    ctx.beginPath();
    ctx.ellipse(bx + 40, by - 25, 7, 5, 0.3, 0, Math.PI * 2);
    ctx.fill();
}

function drawHUD(w, h) {
    // Score panel
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    roundRect(12, 12, 140, 62, 10);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 26px sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(score.toLocaleString(), 22, 42);

    ctx.font = "11px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.6)";
    ctx.fillText("SCORE", 22, 58);

    // Speed bar
    const difficultyT = Math.min(distance / 15000, 1);
    const currentMax = baseSpeed + difficultyT * 42;
    const speedPct = speed / currentMax;
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    ctx.fillRect(22, 64, 110, 4);
    ctx.fillStyle = speedPct > 0.85 ? "#FF5722" : "#4FC3F7";
    ctx.fillRect(22, 64, 110 * speedPct, 4);

    // High score
    if (highScore > 0) {
        ctx.fillStyle = "rgba(0,0,0,0.4)";
        roundRect(w - 110, 12, 98, 30, 8);
        ctx.fill();

        ctx.fillStyle = "#FFC107";
        ctx.font = "bold 11px sans-serif";
        ctx.textAlign = "right";
        ctx.fillText("BEST " + highScore.toLocaleString(), w - 18, 32);
    }

    // Difficulty indicator
    const diff = Math.floor(difficultyT * 100);
    let diffLabel, diffColor;
    if (diff < 20) { diffLabel = "GREEN"; diffColor = "#4CAF50"; }
    else if (diff < 45) { diffLabel = "BLUE"; diffColor = "#2196F3"; }
    else if (diff < 70) { diffLabel = "BLACK"; diffColor = "#555"; }
    else { diffLabel = "DOUBLE BLACK"; diffColor = "#D32F2F"; }

    ctx.fillStyle = "rgba(0,0,0,0.4)";
    roundRect(w / 2 - 50, 12, 100, 22, 6);
    ctx.fill();

    ctx.fillStyle = diffColor;
    ctx.font = "bold 11px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(diffLabel, w / 2, 28);
}

function drawTurnHints(w, h) {
    // Subtle edge glow when turning
    if (touchSide === -1) {
        const grad = ctx.createLinearGradient(0, 0, 60, 0);
        grad.addColorStop(0, "rgba(255,255,255,0.15)");
        grad.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, 60, h);
    } else if (touchSide === 1) {
        const grad = ctx.createLinearGradient(w, 0, w - 60, 0);
        grad.addColorStop(0, "rgba(255,255,255,0.15)");
        grad.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = grad;
        ctx.fillRect(w - 60, 0, 60, h);
    }

    // Tutorial hint at start
    if (distance < 200 && state === STATE.PLAYING) {
        ctx.fillStyle = "rgba(0,0,0,0.35)";
        ctx.font = "13px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("HOLD LEFT / RIGHT TO TURN", w / 2, h * 0.7);
    }
}

function drawMenuScreen() {
    const w = W(), h = H();

    // Sky
    const skyGrad = ctx.createLinearGradient(0, 0, 0, h);
    skyGrad.addColorStop(0, "#6BB3D9");
    skyGrad.addColorStop(0.4, "#9DCCEA");
    skyGrad.addColorStop(1, "#E8F0F8");
    ctx.fillStyle = skyGrad;
    ctx.fillRect(0, 0, w, h);

    drawMountains(w, h);

    // Snow ground
    ctx.fillStyle = "#E8F0F8";
    ctx.fillRect(0, h * HORIZON, w, h);

    drawSnowflakes();

    // Title card
    ctx.fillStyle = "rgba(0,0,0,0.65)";
    roundRect(w / 2 - 140, h * 0.13, 280, 100, 16);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 44px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("SKI RUN", w / 2, h * 0.13 + 50);

    ctx.font = "14px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.6)";
    ctx.fillText("Endless first-person skiing", w / 2, h * 0.13 + 78);

    // High score
    if (highScore > 0) {
        ctx.fillStyle = "#FFC107";
        ctx.font = "bold 16px sans-serif";
        ctx.fillText("Best: " + highScore.toLocaleString(), w / 2, h * 0.38);
    }

    // Play button
    const btnW = 200, btnH = 58;
    const btnY = h * 0.48;

    ctx.fillStyle = "#D32F2F";
    roundRect(w / 2 - btnW / 2, btnY, btnW, btnH, 29);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 22px sans-serif";
    ctx.fillText("START", w / 2, btnY + 37);

    // Instructions
    const instY = h * 0.68;
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    roundRect(w / 2 - 140, instY, 280, 105, 12);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 14px sans-serif";
    ctx.fillText("HOW TO PLAY", w / 2, instY + 24);

    ctx.font = "12px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    ctx.fillText("Hold LEFT side to turn left", w / 2, instY + 46);
    ctx.fillText("Hold RIGHT side to turn right", w / 2, instY + 64);
    ctx.fillText("Dodge obstacles, pass through gates", w / 2, instY + 82);
    ctx.fillText("It only gets faster...", w / 2, instY + 97);

    // Handle tap
    if (tapPos) {
        const tx = tapPos.x, ty = tapPos.y;
        if (tx > w / 2 - btnW / 2 && tx < w / 2 + btnW / 2 && ty > btnY && ty < btnY + btnH) {
            startRun();
        }
        tapPos = null;
    }
}

function drawDeathScreen(w, h) {
    ctx.fillStyle = "rgba(0,0,0,0.55)";
    ctx.fillRect(0, 0, w, h);

    ctx.fillStyle = "#FF5722";
    ctx.font = "bold 38px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("WIPEOUT!", w / 2, h * 0.3);

    ctx.fillStyle = "#fff";
    ctx.font = "bold 28px sans-serif";
    ctx.fillText(score.toLocaleString(), w / 2, h * 0.39);

    ctx.font = "14px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.6)";
    ctx.fillText("SCORE", w / 2, h * 0.43);

    const isNewBest = highScore === score && score > 0;
    if (isNewBest) {
        ctx.fillStyle = "#FFC107";
        ctx.font = "bold 16px sans-serif";
        ctx.fillText("NEW BEST!", w / 2, h * 0.48);
    }

    // Distance stat
    ctx.fillStyle = "rgba(255,255,255,0.5)";
    ctx.font = "13px sans-serif";
    ctx.fillText(Math.floor(distance) + "m traveled", w / 2, h * 0.53);

    // Retry button
    const btnW = 180, btnH = 54;
    const btnY = h * 0.58;

    ctx.fillStyle = "#D32F2F";
    roundRect(w / 2 - btnW / 2, btnY, btnW, btnH, 27);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 20px sans-serif";
    ctx.fillText("RETRY", w / 2, btnY + 34);

    // Menu button
    const btn2Y = btnY + 68;
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    roundRect(w / 2 - btnW / 2, btn2Y, btnW, btnH, 27);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 20px sans-serif";
    ctx.fillText("MENU", w / 2, btn2Y + 34);

    if (tapPos) {
        const tx = tapPos.x, ty = tapPos.y;
        if (tx > w / 2 - btnW / 2 && tx < w / 2 + btnW / 2) {
            if (ty > btnY && ty < btnY + btnH) startRun();
            else if (ty > btn2Y && ty < btn2Y + btnH) state = STATE.MENU;
        }
        tapPos = null;
    }
}

// ── Helpers ──
function roundRect(x, y, w, h, r) {
    ctx.beginPath();
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + w - r, y);
    ctx.quadraticCurveTo(x + w, y, x + w, y + r);
    ctx.lineTo(x + w, y + h - r);
    ctx.quadraticCurveTo(x + w, y + h, x + w - r, y + h);
    ctx.lineTo(x + r, y + h);
    ctx.quadraticCurveTo(x, y + h, x, y + h - r);
    ctx.lineTo(x, y + r);
    ctx.quadraticCurveTo(x, y, x + r, y);
    ctx.closePath();
}

// ── Game loop ──
function gameLoop(timestamp) {
    const dt = Math.min((timestamp - lastTime) / 1000, 0.05);
    lastTime = timestamp;

    update(dt);
    draw();

    requestAnimationFrame(gameLoop);
}

// ── Boot ──
initSnowflakes();
requestAnimationFrame((t) => {
    lastTime = t;
    gameLoop(t);
});
