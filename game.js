// ── Ski Run ── Mobile skiing game with touch controls ──

const canvas = document.getElementById("game");
const ctx = canvas.getContext("2d");

// ── Responsive canvas sizing ──
function resize() {
    canvas.width = window.innerWidth * devicePixelRatio;
    canvas.height = window.innerHeight * devicePixelRatio;
    ctx.scale(devicePixelRatio, devicePixelRatio);
}
window.addEventListener("resize", resize);
resize();

const W = () => window.innerWidth;
const H = () => window.innerHeight;

// ── Game state ──
const STATE = {
    MENU: 0,
    TRAIL_SELECT: 1,
    PLAYING: 2,
    CRASHED: 3,
    FINISHED: 4,
};

let state = STATE.MENU;
let skier, camera, trail, obstacles, gates, score, distanceTraveled, trailLength;
let particles = [];
let snowflakes = [];
let turnDirection = 0; // -1 left, 0 straight, 1 right
let touchSide = 0;
let lastTime = 0;
let highScores = loadHighScores();

// ── Trail definitions ──
const TRAILS = [
    {
        name: "Bunny Hill",
        difficulty: "Green",
        color: "#4CAF50",
        length: 3000,
        treeFrequency: 0.3,
        rockFrequency: 0.05,
        gateFrequency: 0.12,
        width: 350,
        maxSpeed: 6,
        description: "A gentle slope for beginners",
    },
    {
        name: "Blue Ridge",
        difficulty: "Blue",
        color: "#2196F3",
        length: 5000,
        treeFrequency: 0.45,
        rockFrequency: 0.1,
        gateFrequency: 0.1,
        width: 280,
        maxSpeed: 8,
        description: "Moderate terrain with tighter turns",
    },
    {
        name: "Black Diamond",
        difficulty: "Black",
        color: "#333",
        length: 7000,
        treeFrequency: 0.6,
        rockFrequency: 0.18,
        gateFrequency: 0.08,
        width: 220,
        maxSpeed: 11,
        description: "Steep and narrow — experts only",
    },
    {
        name: "Double Black",
        difficulty: "Double Black",
        color: "#1a1a1a",
        length: 9000,
        treeFrequency: 0.75,
        rockFrequency: 0.25,
        gateFrequency: 0.06,
        width: 180,
        maxSpeed: 14,
        description: "The ultimate challenge",
    },
];

// ── High score persistence ──
function loadHighScores() {
    try {
        return JSON.parse(localStorage.getItem("skiRunScores")) || {};
    } catch {
        return {};
    }
}

function saveHighScore(trailName, s) {
    const best = highScores[trailName] || 0;
    if (s > best) {
        highScores[trailName] = s;
        localStorage.setItem("skiRunScores", JSON.stringify(highScores));
        return true;
    }
    return false;
}

// ── Snowflake system (ambient) ──
function initSnowflakes() {
    snowflakes = [];
    for (let i = 0; i < 60; i++) {
        snowflakes.push({
            x: Math.random() * W(),
            y: Math.random() * H(),
            r: Math.random() * 2.5 + 0.5,
            vx: Math.random() * 0.6 - 0.3,
            vy: Math.random() * 1.5 + 0.5,
            opacity: Math.random() * 0.5 + 0.3,
        });
    }
}

function updateSnowflakes(dt) {
    for (const sf of snowflakes) {
        sf.x += sf.vx * dt * 60;
        sf.y += sf.vy * dt * 60;
        if (sf.y > H()) { sf.y = -5; sf.x = Math.random() * W(); }
        if (sf.x < 0) sf.x = W();
        if (sf.x > W()) sf.x = 0;
    }
}

function drawSnowflakes() {
    for (const sf of snowflakes) {
        ctx.beginPath();
        ctx.arc(sf.x, sf.y, sf.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${sf.opacity})`;
        ctx.fill();
    }
}

// ── Particle system (snow spray) ──
function spawnParticles(x, y, dir) {
    for (let i = 0; i < 3; i++) {
        particles.push({
            x,
            y,
            vx: (Math.random() - 0.5) * 2 + dir * 1.5,
            vy: -(Math.random() * 1.5 + 0.5),
            life: 0.4 + Math.random() * 0.3,
            maxLife: 0.4 + Math.random() * 0.3,
            r: Math.random() * 2 + 1,
        });
    }
}

function spawnCrashParticles(x, y) {
    for (let i = 0; i < 25; i++) {
        const angle = Math.random() * Math.PI * 2;
        const speed = Math.random() * 5 + 2;
        particles.push({
            x,
            y,
            vx: Math.cos(angle) * speed,
            vy: Math.sin(angle) * speed,
            life: 0.8 + Math.random() * 0.5,
            maxLife: 0.8 + Math.random() * 0.5,
            r: Math.random() * 3 + 1,
        });
    }
}

function updateParticles(dt) {
    for (let i = particles.length - 1; i >= 0; i--) {
        const p = particles[i];
        p.x += p.vx * dt * 60;
        p.y += p.vy * dt * 60;
        p.life -= dt;
        if (p.life <= 0) particles.splice(i, 1);
    }
}

function drawParticles() {
    for (const p of particles) {
        const alpha = p.life / p.maxLife;
        ctx.beginPath();
        ctx.arc(p.x, p.y - camera.y + H() * 0.35, p.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${alpha * 0.8})`;
        ctx.fill();
    }
}

// ── Obstacle / gate generation ──
function generateTrailContent(t) {
    obstacles = [];
    gates = [];
    const rng = mulberry32(42 + TRAILS.indexOf(t));

    for (let y = 300; y < t.length; y += 40) {
        const halfW = t.width / 2;
        const trailCenterX = getTrailCenter(y, t);

        if (rng() < t.treeFrequency) {
            // Trees outside or along edges of trail
            const side = rng() < 0.5 ? -1 : 1;
            const offset = halfW * (0.5 + rng() * 1.2);
            obstacles.push({
                type: "tree",
                x: trailCenterX + side * offset,
                y,
                hitRadius: 10,
            });
        }

        if (rng() < t.rockFrequency) {
            // Rocks can appear on the trail
            const offset = (rng() - 0.5) * halfW * 1.4;
            obstacles.push({
                type: "rock",
                x: trailCenterX + offset,
                y,
                hitRadius: 9,
            });
        }

        if (rng() < t.gateFrequency && y > 400) {
            const gx = trailCenterX + (rng() - 0.5) * halfW * 0.6;
            gates.push({
                x: gx,
                y,
                passed: false,
                width: 40,
            });
        }
    }
}

// Deterministic RNG
function mulberry32(seed) {
    return function () {
        seed |= 0;
        seed = (seed + 0x6d2b79f5) | 0;
        let t = Math.imul(seed ^ (seed >>> 15), 1 | seed);
        t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
        return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
    };
}

// Trail curves — center X sways as you go down
function getTrailCenter(y, t) {
    const cx = W() / 2;
    const sway1 = Math.sin(y * 0.003) * 60;
    const sway2 = Math.sin(y * 0.0007 + 1.5) * 100;
    const difficultyFactor = TRAILS.indexOf(t) * 0.3 + 1;
    return cx + (sway1 + sway2) * difficultyFactor * 0.4;
}

// ── Initialize a run ──
function startRun(trailIndex) {
    trail = TRAILS[trailIndex];
    skier = {
        x: W() / 2,
        y: 100,
        speed: 0,
        angle: 0, // radians from straight down (0=down, neg=left, pos=right)
        turning: false,
    };
    camera = { y: 0 };
    score = 0;
    distanceTraveled = 0;
    trailLength = trail.length;
    particles = [];
    turnDirection = 0;
    touchSide = 0;
    generateTrailContent(trail);
    state = STATE.PLAYING;
}

// ── Touch / mouse controls ──
function handleInputStart(clientX) {
    if (state === STATE.PLAYING) {
        const mid = W() / 2;
        touchSide = clientX < mid ? -1 : 1;
        turnDirection = touchSide;
    }
}

function handleInputEnd() {
    turnDirection = 0;
    touchSide = 0;
}

canvas.addEventListener("touchstart", (e) => {
    e.preventDefault();
    const touch = e.touches[0];
    handleInputStart(touch.clientX);
}, { passive: false });

canvas.addEventListener("touchmove", (e) => {
    e.preventDefault();
}, { passive: false });

canvas.addEventListener("touchend", (e) => {
    e.preventDefault();
    if (e.touches.length === 0) handleInputEnd();
}, { passive: false });

// Mouse fallback for desktop testing
canvas.addEventListener("mousedown", (e) => handleInputStart(e.clientX));
canvas.addEventListener("mouseup", handleInputEnd);

// Tap detection for menus
let tapPos = null;
canvas.addEventListener("touchstart", (e) => {
    tapPos = { x: e.touches[0].clientX, y: e.touches[0].clientY };
}, { passive: false });
canvas.addEventListener("mousedown", (e) => {
    tapPos = { x: e.clientX, y: e.clientY };
});

// ── Update ──
function update(dt) {
    updateSnowflakes(dt);

    if (state !== STATE.PLAYING) return;

    // Accelerate
    const maxSpd = trail.maxSpeed;
    skier.speed = Math.min(skier.speed + dt * 3, maxSpd);

    // Turning
    const turnRate = 2.8;
    const maxAngle = Math.PI / 3;
    if (turnDirection !== 0) {
        skier.angle += turnDirection * turnRate * dt;
        skier.angle = Math.max(-maxAngle, Math.min(maxAngle, skier.angle));
        // Turning slows you down a little
        skier.speed *= 1 - 0.3 * dt;
        // Snow spray
        spawnParticles(skier.x, skier.y, -turnDirection);
    } else {
        // Straighten out gradually
        skier.angle *= 1 - 3 * dt;
        if (Math.abs(skier.angle) < 0.01) skier.angle = 0;
    }

    // Move skier
    const dx = Math.sin(skier.angle) * skier.speed * dt * 60;
    const dy = Math.cos(skier.angle) * skier.speed * dt * 60;
    skier.x += dx;
    skier.y += dy;
    distanceTraveled = skier.y;

    // Keep skier on screen horizontally (with some padding)
    const pad = 20;
    skier.x = Math.max(pad, Math.min(W() - pad, skier.x));

    // Camera follows skier
    camera.y = skier.y - H() * 0.35;

    // Check gate passes
    for (const g of gates) {
        if (!g.passed && skier.y > g.y && skier.y < g.y + 30) {
            if (Math.abs(skier.x - g.x) < g.width / 2 + 10) {
                g.passed = true;
                score += 100;
                // Gate pass particles
                for (let i = 0; i < 8; i++) {
                    particles.push({
                        x: g.x + (Math.random() - 0.5) * g.width,
                        y: g.y,
                        vx: (Math.random() - 0.5) * 3,
                        vy: -(Math.random() * 2 + 1),
                        life: 0.5,
                        maxLife: 0.5,
                        r: 2,
                    });
                }
            }
        }
    }

    // Collision detection
    const screenY = skier.y;
    for (const ob of obstacles) {
        const dx2 = skier.x - ob.x;
        const dy2 = screenY - ob.y;
        const dist = Math.sqrt(dx2 * dx2 + dy2 * dy2);
        if (dist < ob.hitRadius + 8) {
            // Crash!
            spawnCrashParticles(skier.x, skier.y);
            state = STATE.CRASHED;
            skier.speed = 0;
            return;
        }
    }

    // Distance-based score
    score += skier.speed * dt * 5;

    // Check finish
    if (skier.y >= trailLength) {
        state = STATE.FINISHED;
        score = Math.floor(score);
        saveHighScore(trail.name, score);
    }

    updateParticles(dt);
}

// ── Draw ──
function draw() {
    const w = W();
    const h = H();

    // Sky gradient
    const skyGrad = ctx.createLinearGradient(0, 0, 0, h);
    skyGrad.addColorStop(0, "#87CEEB");
    skyGrad.addColorStop(0.6, "#B0D4E8");
    skyGrad.addColorStop(1, "#E8F0F8");
    ctx.fillStyle = skyGrad;
    ctx.fillRect(0, 0, w, h);

    drawSnowflakes();

    if (state === STATE.MENU) {
        drawMenu();
        return;
    }

    if (state === STATE.TRAIL_SELECT) {
        drawTrailSelect();
        return;
    }

    // ── Game view ──
    const camY = camera.y;

    // Draw snow ground
    ctx.fillStyle = "#F0F4F8";
    ctx.fillRect(0, 0, w, h);

    // Draw trail boundaries
    drawTrail(camY);

    // Draw gates
    for (const g of gates) {
        const sy = g.y - camY;
        if (sy < -50 || sy > h + 50) continue;
        drawGate(g.x, sy, g.width, g.passed);
    }

    // Draw obstacles
    for (const ob of obstacles) {
        const sy = ob.y - camY;
        if (sy < -50 || sy > h + 50) continue;
        if (ob.type === "tree") drawTree(ob.x, sy);
        else drawRock(ob.x, sy);
    }

    // Draw particles
    drawParticles();

    // Draw skier
    const skierScreenY = skier.y - camY;
    drawSkier(skier.x, skierScreenY, skier.angle);

    // Draw HUD
    drawHUD();

    // Draw turn indicators
    if (state === STATE.PLAYING) {
        drawTurnIndicators();
    }

    // Crash overlay
    if (state === STATE.CRASHED) {
        drawCrashScreen();
    }

    // Finish overlay
    if (state === STATE.FINISHED) {
        drawFinishScreen();
    }
}

function drawTrail(camY) {
    const w = W();
    const h = H();

    // Draw trail corridor
    for (let sy = -20; sy < h + 20; sy += 4) {
        const worldY = sy + camY;
        const cx = getTrailCenter(worldY, trail);
        const halfW = trail.width / 2;

        // Trail surface (groomed snow)
        ctx.fillStyle = "#FAFEFF";
        ctx.fillRect(cx - halfW, sy, trail.width, 4);

        // Trail edge markers
        ctx.fillStyle = "rgba(180,200,220,0.4)";
        ctx.fillRect(cx - halfW - 2, sy, 3, 4);
        ctx.fillRect(cx + halfW - 1, sy, 3, 4);
    }

    // Ski tracks (faint lines behind skier)
    if (state === STATE.PLAYING && skier.speed > 1) {
        ctx.strokeStyle = "rgba(190,210,230,0.3)";
        ctx.lineWidth = 1.5;
        const trackOffset = 5;
        for (let i = 0; i < 2; i++) {
            const side = i === 0 ? -1 : 1;
            ctx.beginPath();
            ctx.moveTo(skier.x + side * trackOffset, skier.y - camY);
            ctx.lineTo(
                skier.x + side * trackOffset - Math.sin(skier.angle) * 40,
                skier.y - camY + 40
            );
            ctx.stroke();
        }
    }
}

function drawTree(x, y) {
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.1)";
    ctx.beginPath();
    ctx.ellipse(x + 3, y + 18, 10, 4, 0, 0, Math.PI * 2);
    ctx.fill();

    // Trunk
    ctx.fillStyle = "#5D4037";
    ctx.fillRect(x - 2, y + 5, 4, 13);

    // Foliage layers
    const greens = ["#1B5E20", "#2E7D32", "#388E3C"];
    for (let i = 0; i < 3; i++) {
        ctx.fillStyle = greens[i];
        ctx.beginPath();
        ctx.moveTo(x, y - 12 + i * 7);
        ctx.lineTo(x - 10 + i * 1.5, y + 2 + i * 5);
        ctx.lineTo(x + 10 - i * 1.5, y + 2 + i * 5);
        ctx.closePath();
        ctx.fill();
    }

    // Snow on top
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.moveTo(x, y - 13);
    ctx.lineTo(x - 5, y - 6);
    ctx.lineTo(x + 5, y - 6);
    ctx.closePath();
    ctx.fill();
}

function drawRock(x, y) {
    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.1)";
    ctx.beginPath();
    ctx.ellipse(x + 2, y + 8, 9, 3, 0, 0, Math.PI * 2);
    ctx.fill();

    // Rock body
    ctx.fillStyle = "#78909C";
    ctx.beginPath();
    ctx.moveTo(x - 8, y + 5);
    ctx.lineTo(x - 5, y - 4);
    ctx.lineTo(x + 2, y - 6);
    ctx.lineTo(x + 8, y - 2);
    ctx.lineTo(x + 7, y + 5);
    ctx.closePath();
    ctx.fill();

    // Highlight
    ctx.fillStyle = "#90A4AE";
    ctx.beginPath();
    ctx.moveTo(x - 3, y - 2);
    ctx.lineTo(x + 1, y - 5);
    ctx.lineTo(x + 5, y - 2);
    ctx.lineTo(x, y + 1);
    ctx.closePath();
    ctx.fill();

    // Snow cap
    ctx.fillStyle = "#E8E8E8";
    ctx.beginPath();
    ctx.moveTo(x - 4, y - 3);
    ctx.lineTo(x + 1, y - 6);
    ctx.lineTo(x + 6, y - 2);
    ctx.lineTo(x + 2, y - 1);
    ctx.closePath();
    ctx.fill();
}

function drawGate(x, y, width, passed) {
    const half = width / 2;
    const color = passed ? "rgba(76,175,80,0.5)" : "#F44336";

    // Poles
    ctx.fillStyle = color;
    ctx.fillRect(x - half - 2, y - 15, 4, 25);
    ctx.fillRect(x + half - 2, y - 15, 4, 25);

    // Banner
    ctx.fillStyle = passed ? "rgba(76,175,80,0.3)" : "rgba(244,67,54,0.25)";
    ctx.fillRect(x - half, y - 12, width, 8);

    // Stripes on poles
    if (!passed) {
        ctx.fillStyle = "#fff";
        for (let i = 0; i < 3; i++) {
            ctx.fillRect(x - half - 2, y - 13 + i * 8, 4, 3);
            ctx.fillRect(x + half - 2, y - 13 + i * 8, 4, 3);
        }
    }

    if (passed) {
        ctx.fillStyle = "rgba(76,175,80,0.7)";
        ctx.font = "bold 12px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("+100", x, y - 18);
    }
}

function drawSkier(x, y, angle) {
    ctx.save();
    ctx.translate(x, y);
    ctx.rotate(angle);

    // Shadow
    ctx.fillStyle = "rgba(0,0,0,0.15)";
    ctx.beginPath();
    ctx.ellipse(3, 14, 8, 3, 0, 0, Math.PI * 2);
    ctx.fill();

    // Skis
    ctx.strokeStyle = "#333";
    ctx.lineWidth = 2.5;
    ctx.lineCap = "round";
    ctx.beginPath();
    ctx.moveTo(-5, -10);
    ctx.lineTo(-5, 14);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(5, -10);
    ctx.lineTo(5, 14);
    ctx.stroke();

    // Ski tips (curved up)
    ctx.beginPath();
    ctx.moveTo(-5, -10);
    ctx.quadraticCurveTo(-5, -15, -3, -16);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(5, -10);
    ctx.quadraticCurveTo(5, -15, 3, -16);
    ctx.stroke();

    // Body
    ctx.fillStyle = "#D32F2F"; // Red jacket
    ctx.beginPath();
    ctx.ellipse(0, 0, 6, 8, 0, 0, Math.PI * 2);
    ctx.fill();

    // Head
    ctx.fillStyle = "#FFE0B2";
    ctx.beginPath();
    ctx.arc(0, -10, 5, 0, Math.PI * 2);
    ctx.fill();

    // Helmet
    ctx.fillStyle = "#1565C0";
    ctx.beginPath();
    ctx.arc(0, -11, 5, Math.PI, 0);
    ctx.fill();

    // Goggles
    ctx.fillStyle = "#FFC107";
    ctx.fillRect(-4, -11, 8, 2);

    // Poles (when turning)
    if (turnDirection !== 0) {
        ctx.strokeStyle = "#666";
        ctx.lineWidth = 1.5;
        const poleAngle = turnDirection * 0.4;
        ctx.beginPath();
        ctx.moveTo(-6, -2);
        ctx.lineTo(-14 - Math.sin(poleAngle) * 5, 10);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(6, -2);
        ctx.lineTo(14 + Math.sin(poleAngle) * 5, 10);
        ctx.stroke();
    } else {
        ctx.strokeStyle = "#666";
        ctx.lineWidth = 1.5;
        ctx.beginPath();
        ctx.moveTo(-6, -2);
        ctx.lineTo(-8, 12);
        ctx.stroke();
        ctx.beginPath();
        ctx.moveTo(6, -2);
        ctx.lineTo(8, 12);
        ctx.stroke();
    }

    ctx.restore();
}

function drawTurnIndicators() {
    const w = W();
    const h = H();
    const alpha = 0.08;

    if (touchSide === -1) {
        // Left side highlight
        const grad = ctx.createLinearGradient(0, 0, 80, 0);
        grad.addColorStop(0, `rgba(255,255,255,${alpha * 3})`);
        grad.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = grad;
        ctx.fillRect(0, 0, 80, h);
    } else if (touchSide === 1) {
        // Right side highlight
        const grad = ctx.createLinearGradient(w, 0, w - 80, 0);
        grad.addColorStop(0, `rgba(255,255,255,${alpha * 3})`);
        grad.addColorStop(1, "rgba(255,255,255,0)");
        ctx.fillStyle = grad;
        ctx.fillRect(w - 80, 0, 80, h);
    }

    // Show touch hints at bottom
    if (skier.y < 400) {
        ctx.fillStyle = "rgba(0,0,0,0.3)";
        ctx.font = "14px sans-serif";
        ctx.textAlign = "center";
        ctx.fillText("Hold left side to turn left", w * 0.25, h - 30);
        ctx.fillText("Hold right side to turn right", w * 0.75, h - 30);
    }
}

function drawHUD() {
    const w = W();

    // Score
    ctx.fillStyle = "rgba(0,0,0,0.6)";
    roundRect(10, 10, 130, 70, 10);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 22px sans-serif";
    ctx.textAlign = "left";
    ctx.fillText(Math.floor(score), 20, 38);

    ctx.font = "12px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.7)";
    ctx.fillText("SCORE", 20, 55);

    // Speed bar
    const speedPct = skier.speed / trail.maxSpeed;
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    ctx.fillRect(20, 62, 100, 6);
    ctx.fillStyle = speedPct > 0.8 ? "#FF5722" : "#4CAF50";
    ctx.fillRect(20, 62, 100 * speedPct, 6);

    // Progress
    const progress = Math.min(1, distanceTraveled / trailLength);
    ctx.fillStyle = "rgba(0,0,0,0.6)";
    roundRect(w - 55, 10, 45, 200, 10);
    ctx.fill();

    // Progress track
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    ctx.fillRect(w - 38, 30, 10, 160);

    // Progress fill
    ctx.fillStyle = trail.color;
    const progH = 160 * progress;
    ctx.fillRect(w - 38, 30 + (160 - progH), 10, progH);

    // Progress marker
    ctx.fillStyle = "#fff";
    ctx.beginPath();
    ctx.arc(w - 33, 30 + 160 * (1 - progress), 6, 0, Math.PI * 2);
    ctx.fill();

    // Mountain icon at top
    ctx.fillStyle = "#fff";
    ctx.font = "10px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("TOP", w - 33, 26);
    ctx.fillText("END", w - 33, 200);

    // Trail name
    ctx.fillStyle = "rgba(0,0,0,0.4)";
    ctx.font = "11px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText(trail.name, w / 2, 22);
}

function drawMenu() {
    const w = W();
    const h = H();

    // Mountain backdrop
    drawMountains(w, h);

    // Title
    ctx.fillStyle = "rgba(0,0,0,0.7)";
    roundRect(w / 2 - 130, h * 0.15, 260, 90, 15);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 42px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("SKI RUN", w / 2, h * 0.15 + 45);

    ctx.font = "14px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.7)";
    ctx.fillText("A mobile skiing game", w / 2, h * 0.15 + 72);

    // Play button
    const btnY = h * 0.52;
    const btnW = 200;
    const btnH = 56;

    ctx.fillStyle = "#D32F2F";
    roundRect(w / 2 - btnW / 2, btnY, btnW, btnH, 28);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "bold 20px sans-serif";
    ctx.fillText("START", w / 2, btnY + 35);

    // Instructions
    const instY = h * 0.72;
    ctx.fillStyle = "rgba(0,0,0,0.5)";
    roundRect(w / 2 - 140, instY, 280, 100, 12);
    ctx.fill();

    ctx.fillStyle = "#fff";
    ctx.font = "14px sans-serif";
    ctx.fillText("HOW TO PLAY", w / 2, instY + 24);

    ctx.font = "12px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.8)";
    ctx.fillText("Hold LEFT side of screen to turn left", w / 2, instY + 46);
    ctx.fillText("Hold RIGHT side of screen to turn right", w / 2, instY + 64);
    ctx.fillText("Avoid trees and rocks, pass through gates!", w / 2, instY + 82);

    // Handle tap
    if (tapPos) {
        const tx = tapPos.x, ty = tapPos.y;
        if (
            tx > w / 2 - btnW / 2 && tx < w / 2 + btnW / 2 &&
            ty > btnY && ty < btnY + btnH
        ) {
            state = STATE.TRAIL_SELECT;
        }
        tapPos = null;
    }
}

function drawMountains(w, h) {
    // Distant mountains
    ctx.fillStyle = "#B0BEC5";
    ctx.beginPath();
    ctx.moveTo(0, h * 0.45);
    ctx.lineTo(w * 0.15, h * 0.2);
    ctx.lineTo(w * 0.3, h * 0.38);
    ctx.lineTo(w * 0.5, h * 0.12);
    ctx.lineTo(w * 0.7, h * 0.35);
    ctx.lineTo(w * 0.85, h * 0.18);
    ctx.lineTo(w, h * 0.4);
    ctx.lineTo(w, h);
    ctx.lineTo(0, h);
    ctx.closePath();
    ctx.fill();

    // Snow caps
    ctx.fillStyle = "#E8EAF0";
    ctx.beginPath();
    ctx.moveTo(w * 0.5, h * 0.12);
    ctx.lineTo(w * 0.43, h * 0.22);
    ctx.lineTo(w * 0.57, h * 0.22);
    ctx.closePath();
    ctx.fill();

    ctx.beginPath();
    ctx.moveTo(w * 0.85, h * 0.18);
    ctx.lineTo(w * 0.8, h * 0.26);
    ctx.lineTo(w * 0.9, h * 0.26);
    ctx.closePath();
    ctx.fill();

    // Foreground snow
    ctx.fillStyle = "#E8F0F8";
    ctx.fillRect(0, h * 0.42, w, h);
}

function drawTrailSelect() {
    const w = W();
    const h = H();

    drawMountains(w, h);

    ctx.fillStyle = "rgba(0,0,0,0.6)";
    ctx.font = "bold 24px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("SELECT TRAIL", w / 2, 50);

    const cardH = 80;
    const cardW = Math.min(320, w - 40);
    const startY = 80;

    for (let i = 0; i < TRAILS.length; i++) {
        const t = TRAILS[i];
        const cy = startY + i * (cardH + 12);

        // Card background
        ctx.fillStyle = "rgba(0,0,0,0.55)";
        roundRect(w / 2 - cardW / 2, cy, cardW, cardH, 12);
        ctx.fill();

        // Difficulty dot
        ctx.fillStyle = t.color;
        if (t.difficulty === "Double Black") {
            // Two diamonds
            drawDiamond(w / 2 - cardW / 2 + 24, cy + 24, 7);
            drawDiamond(w / 2 - cardW / 2 + 38, cy + 24, 7);
        } else if (t.difficulty === "Black") {
            drawDiamond(w / 2 - cardW / 2 + 28, cy + 24, 9);
        } else {
            ctx.beginPath();
            ctx.arc(w / 2 - cardW / 2 + 28, cy + 24, 9, 0, Math.PI * 2);
            ctx.fill();
        }

        // Trail name
        ctx.fillStyle = "#fff";
        ctx.font = "bold 18px sans-serif";
        ctx.textAlign = "left";
        ctx.fillText(t.name, w / 2 - cardW / 2 + 52, cy + 28);

        // Description
        ctx.font = "12px sans-serif";
        ctx.fillStyle = "rgba(255,255,255,0.7)";
        ctx.fillText(t.description, w / 2 - cardW / 2 + 52, cy + 48);

        // High score
        const hs = highScores[t.name];
        if (hs) {
            ctx.fillStyle = "#FFC107";
            ctx.font = "bold 12px sans-serif";
            ctx.textAlign = "right";
            ctx.fillText("Best: " + Math.floor(hs), w / 2 + cardW / 2 - 15, cy + 28);
        }

        // Length indicator
        ctx.fillStyle = "rgba(255,255,255,0.4)";
        ctx.font = "11px sans-serif";
        ctx.textAlign = "right";
        ctx.fillText(t.length + "m", w / 2 + cardW / 2 - 15, cy + 48);

        // Trail width bar
        ctx.fillStyle = "rgba(255,255,255,0.15)";
        ctx.fillRect(w / 2 - cardW / 2 + 52, cy + 58, cardW - 70, 6);
        const widthPct = t.width / 350;
        ctx.fillStyle = t.color === "#333" || t.color === "#1a1a1a" ? "#fff" : t.color;
        ctx.fillRect(w / 2 - cardW / 2 + 52, cy + 58, (cardW - 70) * widthPct, 6);

        ctx.fillStyle = "rgba(255,255,255,0.4)";
        ctx.font = "9px sans-serif";
        ctx.textAlign = "left";
        ctx.fillText("TRAIL WIDTH", w / 2 - cardW / 2 + 52, cy + 74);
    }

    // Back button
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    roundRect(15, 15, 60, 30, 8);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "14px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("BACK", 45, 35);

    // Handle tap
    if (tapPos) {
        const tx = tapPos.x, ty = tapPos.y;

        // Back button
        if (tx > 15 && tx < 75 && ty > 15 && ty < 45) {
            state = STATE.MENU;
            tapPos = null;
            return;
        }

        for (let i = 0; i < TRAILS.length; i++) {
            const cy = startY + i * (cardH + 12);
            if (
                tx > w / 2 - cardW / 2 && tx < w / 2 + cardW / 2 &&
                ty > cy && ty < cy + cardH
            ) {
                startRun(i);
                tapPos = null;
                return;
            }
        }
        tapPos = null;
    }
}

function drawCrashScreen() {
    const w = W();
    const h = H();

    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(0, 0, w, h);

    // Crash text
    ctx.fillStyle = "#FF5722";
    ctx.font = "bold 36px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("CRASHED!", w / 2, h * 0.35);

    ctx.fillStyle = "#fff";
    ctx.font = "20px sans-serif";
    ctx.fillText("Score: " + Math.floor(score), w / 2, h * 0.43);

    ctx.font = "14px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.7)";
    const pct = Math.floor((distanceTraveled / trailLength) * 100);
    ctx.fillText(pct + "% of trail completed", w / 2, h * 0.49);

    // Retry button
    const btnW = 160;
    const btnH = 50;
    const btnY = h * 0.56;

    ctx.fillStyle = "#D32F2F";
    roundRect(w / 2 - btnW / 2, btnY, btnW, btnH, 25);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 18px sans-serif";
    ctx.fillText("RETRY", w / 2, btnY + 32);

    // Menu button
    const btn2Y = btnY + 65;
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    roundRect(w / 2 - btnW / 2, btn2Y, btnW, btnH, 25);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 18px sans-serif";
    ctx.fillText("TRAILS", w / 2, btn2Y + 32);

    if (tapPos) {
        const tx = tapPos.x, ty = tapPos.y;
        if (tx > w / 2 - btnW / 2 && tx < w / 2 + btnW / 2) {
            if (ty > btnY && ty < btnY + btnH) {
                startRun(TRAILS.indexOf(trail));
            } else if (ty > btn2Y && ty < btn2Y + btnH) {
                state = STATE.TRAIL_SELECT;
            }
        }
        tapPos = null;
    }
}

function drawFinishScreen() {
    const w = W();
    const h = H();

    ctx.fillStyle = "rgba(0,0,0,0.5)";
    ctx.fillRect(0, 0, w, h);

    const isNewBest = highScores[trail.name] === score;

    ctx.fillStyle = "#4CAF50";
    ctx.font = "bold 32px sans-serif";
    ctx.textAlign = "center";
    ctx.fillText("TRAIL COMPLETE!", w / 2, h * 0.3);

    if (isNewBest) {
        ctx.fillStyle = "#FFC107";
        ctx.font = "bold 16px sans-serif";
        ctx.fillText("NEW BEST SCORE!", w / 2, h * 0.37);
    }

    ctx.fillStyle = "#fff";
    ctx.font = "bold 28px sans-serif";
    ctx.fillText(Math.floor(score), w / 2, h * 0.45);

    ctx.font = "14px sans-serif";
    ctx.fillStyle = "rgba(255,255,255,0.7)";
    const gatesPassed = gates.filter((g) => g.passed).length;
    ctx.fillText(
        gatesPassed + " / " + gates.length + " gates passed",
        w / 2,
        h * 0.51
    );

    // Retry button
    const btnW = 160;
    const btnH = 50;
    const btnY = h * 0.58;

    ctx.fillStyle = "#4CAF50";
    roundRect(w / 2 - btnW / 2, btnY, btnW, btnH, 25);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 18px sans-serif";
    ctx.fillText("AGAIN", w / 2, btnY + 32);

    // Menu button
    const btn2Y = btnY + 65;
    ctx.fillStyle = "rgba(255,255,255,0.2)";
    roundRect(w / 2 - btnW / 2, btn2Y, btnW, btnH, 25);
    ctx.fill();
    ctx.fillStyle = "#fff";
    ctx.font = "bold 18px sans-serif";
    ctx.fillText("TRAILS", w / 2, btn2Y + 32);

    if (tapPos) {
        const tx = tapPos.x, ty = tapPos.y;
        if (tx > w / 2 - btnW / 2 && tx < w / 2 + btnW / 2) {
            if (ty > btnY && ty < btnY + btnH) {
                startRun(TRAILS.indexOf(trail));
            } else if (ty > btn2Y && ty < btn2Y + btnH) {
                state = STATE.TRAIL_SELECT;
            }
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

function drawDiamond(x, y, size) {
    ctx.beginPath();
    ctx.moveTo(x, y - size);
    ctx.lineTo(x + size, y);
    ctx.lineTo(x, y + size);
    ctx.lineTo(x - size, y);
    ctx.closePath();
    ctx.fill();
}

// ── Game loop ──
function gameLoop(timestamp) {
    const dt = Math.min((timestamp - lastTime) / 1000, 0.05); // cap delta
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
