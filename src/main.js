import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import toasterUrl from '../toaster.glb?url';
import './style.css';

const $ = (selector) => document.querySelector(selector);
const ui = {
  app: $('#app'),
  canvas: $('#scene'),
  game: $('#game'),
  score: $('#score'),
  best: $('#best'),
  streak: $('#streak'),
  streakWrap: $('.streak'),
  status: $('#statusPill'),
  eyebrow: $('#eyebrow'),
  headline: $('#headline'),
  subcopy: $('#subcopy'),
  gameCopy: $('#gameCopy'),
  toasterMenu: $('#toasterMenu'),
  difficultyReadout: $('#difficultyReadout'),
  difficultyName: $('#difficultyName'),
  knobHitbox: $('#knobHitbox'),
  knobGuide: $('#knobGuide'),
  frontSound: $('#frontSound'),
  frontHaptics: $('#frontHaptics'),
  frontSettings: $('#frontSettings'),
  frontRanks: $('#frontRanks'),
  buttonBankHitbox: $('#buttonBankHitbox'),
  leverGuide: $('#leverGuide'),
  leverHitbox: $('#leverHitbox'),
  stopButton: $('#stopButton'),
  heatLines: $('#heatLines'),
  heatMeter: $('#heatMeter'),
  heatSegments: [...document.querySelectorAll('#heatMeter i')],
  scoreFly: $('#scoreFly'),
  comboBadge: $('#comboBadge'),
  modeChip: $('#modeChip'),
  resultCard: $('#resultCard'),
  resultKicker: $('#resultKicker'),
  resultPoints: $('#resultPoints'),
  resultTiming: $('#resultTiming'),
  soundButton: $('#soundButton'),
  helpButton: $('#helpButton'),
  helpDialog: $('#helpDialog'),
  dialogClose: $('#dialogClose'),
  dialogOk: $('#dialogOk'),
  settingsSound: $('#settingsSound'),
  settingsHaptics: $('#settingsHaptics'),
  ranksDialog: $('#ranksDialog'),
  ranksClose: $('#ranksClose'),
  ranksOk: $('#ranksOk'),
  rankBest: $('#rankBest'),
  rankStreak: $('#rankStreak'),
  rankPerfects: $('#rankPerfects'),
  loadingScreen: $('#loadingScreen'),
  loadingBar: $('#loadingBar'),
};

const clamp = (value, min, max) => Math.min(max, Math.max(min, value));
const easeOutBack = (t) => 1 + 2.70158 * Math.pow(t - 1, 3) + 1.70158 * Math.pow(t - 1, 2);
const formatScore = (value) => String(value).padStart(4, '0');
const supportedModes = ['soft', 'golden', 'crispy', 'chaos'];

function readSetting(key, fallback) {
  try {
    const value = localStorage.getItem(key);
    return value ?? fallback;
  } catch {
    return fallback;
  }
}

function writeSetting(key, value) {
  try { localStorage.setItem(key, String(value)); } catch { /* Storage can be unavailable in private contexts. */ }
}

const storedBest = Number(readSetting('toastyy-best', 0));
const storedMode = readSetting('toastyy-mode', 'golden');

const game = {
  state: 'loading',
  score: 0,
  displayScore: 0,
  best: Number.isFinite(storedBest) && storedBest >= 0 ? storedBest : 0,
  bestStreak: Math.max(0, Number(readSetting('toastyy-best-streak', 0)) || 0),
  perfects: Math.max(0, Number(readSetting('toastyy-perfects', 0)) || 0),
  streak: 0,
  muted: readSetting('toastyy-muted', 'false') === 'true',
  haptics: readSetting('toastyy-haptics', 'true') !== 'false',
  mode: supportedModes.includes(storedMode) ? storedMode : 'golden',
  leverProgress: 0,
  roundStart: 0,
  popAt: 0,
  dangerAt: 0,
  resetAt: 0,
  round: 0,
  dragging: false,
  dragStartY: 0,
  dragStartProgress: 0,
  leverNotch: 0,
  knobDragging: false,
  knobStartX: 0,
  knobStartIndex: 0,
  knobMoved: false,
  pendingRunReset: false,
  hiddenAt: 0,
  nextTickAt: 0,
  dangerBuzzed: false,
};

const modes = {
  soft: { label: 'SOFT', min: 3700, range: 1500, multiplier: 0.8 },
  golden: { label: 'GOLDEN', min: 2800, range: 1450, multiplier: 1 },
  crispy: { label: 'CRISPY', min: 2100, range: 1150, multiplier: 1.25 },
  chaos: { label: 'CHAOS', min: 1450, range: 950, multiplier: 1.6 },
};
const modeOrder = Object.keys(modes);

ui.best.textContent = formatScore(game.best);
ui.soundButton.setAttribute('aria-pressed', String(game.muted));
ui.soundButton.setAttribute('aria-label', game.muted ? 'Turn sound on' : 'Mute sound');
ui.difficultyName.textContent = modes[game.mode].label;
ui.modeChip.textContent = `${modes[game.mode].label} · ${modes[game.mode].multiplier.toFixed(1)}×`;
ui.toasterMenu.inert = true;
ui.toasterMenu.setAttribute('aria-hidden', 'true');

const renderer = new THREE.WebGLRenderer({ canvas: ui.canvas, antialias: true, alpha: true, powerPreference: 'high-performance' });
const reducedQuality = (navigator.deviceMemory && navigator.deviceMemory <= 4) || (navigator.hardwareConcurrency && navigator.hardwareConcurrency <= 4);
renderer.setPixelRatio(Math.min(window.devicePixelRatio, reducedQuality ? 1.5 : 2));
renderer.outputColorSpace = THREE.SRGBColorSpace;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = 1.22;
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;

const scene = new THREE.Scene();
const environmentGenerator = new THREE.PMREMGenerator(renderer);
const roomEnvironment = new RoomEnvironment();
scene.environment = environmentGenerator.fromScene(roomEnvironment, 0.035).texture;
roomEnvironment.dispose();
environmentGenerator.dispose();
const camera = new THREE.PerspectiveCamera(27, 1, 0.01, 20);
camera.position.set(-0.68, 0.26, 0);
camera.lookAt(0, 0.09, 0);

const stage = new THREE.Group();
stage.position.set(0.012, -0.02, 0);
scene.add(stage);

const heaterLight = new THREE.PointLight(0xff5a20, 0, 0.48, 2.2);
heaterLight.position.set(-0.02, 0.165, 0);
stage.add(heaterLight);

scene.add(new THREE.HemisphereLight(0xfff5dc, 0x6f604b, 2.35));
const keyLight = new THREE.DirectionalLight(0xfff2d7, 4.6);
keyLight.position.set(-1.2, 1.9, 1.8);
keyLight.castShadow = true;
keyLight.shadow.mapSize.set(reducedQuality ? 512 : 1024, reducedQuality ? 512 : 1024);
keyLight.shadow.camera.left = -0.5;
keyLight.shadow.camera.right = 0.5;
keyLight.shadow.camera.top = 0.5;
keyLight.shadow.camera.bottom = -0.5;
scene.add(keyLight);
const rimLight = new THREE.DirectionalLight(0xff9b4a, 2.3);
rimLight.position.set(1.2, 0.7, -1.1);
scene.add(rimLight);

const floor = new THREE.Mesh(
  new THREE.CircleGeometry(0.31, 72),
  new THREE.MeshStandardMaterial({ color: 0xd8cbb5, transparent: true, opacity: 0.32, roughness: 1, depthWrite: false }),
);
floor.rotation.x = -Math.PI / 2;
floor.position.set(0, -0.022, 0);
floor.receiveShadow = true;
stage.add(floor);

const shadowCanvas = document.createElement('canvas');
shadowCanvas.width = 128;
shadowCanvas.height = 128;
const shadowContext = shadowCanvas.getContext('2d');
const shadowGradient = shadowContext.createRadialGradient(64, 64, 5, 64, 64, 62);
shadowGradient.addColorStop(0, 'rgba(62,45,25,.48)');
shadowGradient.addColorStop(.48, 'rgba(62,45,25,.24)');
shadowGradient.addColorStop(1, 'rgba(62,45,25,0)');
shadowContext.fillStyle = shadowGradient;
shadowContext.fillRect(0, 0, 128, 128);
const shadow = new THREE.Mesh(
  new THREE.PlaneGeometry(0.46, 0.25),
  new THREE.MeshBasicMaterial({ map: new THREE.CanvasTexture(shadowCanvas), transparent: true, opacity: 0.52, depthWrite: false }),
);
shadow.rotation.x = -Math.PI / 2;
shadow.position.set(0, -0.0185, 0.012);
stage.add(shadow);

let toaster;
let leverParts = [];
let heaterMeshes = [];
let knobMesh;
let buttonBankMesh;
let buttonBankBasePositions;
let leverInsertVertexIndices = [];
const buttonVertexIndices = { sound: [], haptics: [], settings: [], ranks: [] };
const buttonPresses = {
  sound: { depth: 0, target: 0 },
  haptics: { depth: 0, target: 0 },
  settings: { depth: 0, target: 0 },
  ranks: { depth: 0, target: 0 },
};
let knobAngle = 0;
let knobTargetAngle = 0;
const controlPoints = {
  sound: new THREE.Vector3(-0.1124, 0.1141, -0.0379),
  haptics: new THREE.Vector3(-0.1124, 0.0988, -0.0379),
  settings: new THREE.Vector3(-0.1124, 0.0835, -0.0379),
  ranks: new THREE.Vector3(-0.1124, 0.0682, -0.0379),
};
const projectedControls = {};
let toastGroup;
let toastBaseY = 0.177;
let toastPop = 0;
let toastTarget = 0;
let toastMotionActive = false;
const crumbParticles = [];
const smokeParticles = [];
let presentation = 0;
let presentationTarget = 0;
let visualHeat = 0;
let visualDanger = 0;
let latchKick = 0;
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

function roundedRectShape(width, height, radius) {
  const x = -width / 2;
  const y = 0;
  const shape = new THREE.Shape();
  shape.moveTo(x + radius, y);
  shape.lineTo(x + width - radius, y);
  shape.quadraticCurveTo(x + width, y, x + width, y + radius);
  shape.lineTo(x + width, y + height - radius);
  shape.quadraticCurveTo(x + width, y + height, x + width - radius, y + height);
  shape.lineTo(x + radius, y + height);
  shape.quadraticCurveTo(x, y + height, x, y + height - radius);
  shape.lineTo(x, y + radius);
  shape.quadraticCurveTo(x, y, x + radius, y);
  return shape;
}

function createToast() {
  toastGroup = new THREE.Group();
  const crust = new THREE.MeshStandardMaterial({ color: 0xb9672d, roughness: 0.82 });
  const bread = new THREE.MeshStandardMaterial({ color: 0xf4c66f, roughness: 0.9 });
  const toastShape = roundedRectShape(0.075, 0.079, 0.014);
  const crustGeo = new THREE.ExtrudeGeometry(toastShape, { depth: 0.008, bevelEnabled: true, bevelSegments: 3, steps: 1, bevelSize: 0.004, bevelThickness: 0.003 });
  crustGeo.center();
  const breadShape = roundedRectShape(0.063, 0.068, 0.011);
  const breadGeo = new THREE.ExtrudeGeometry(breadShape, { depth: 0.009, bevelEnabled: true, bevelSegments: 2, steps: 1, bevelSize: 0.0025, bevelThickness: 0.002 });
  breadGeo.center();

  [-0.027, 0.027].forEach((z, index) => {
    const slice = new THREE.Group();
    const outer = new THREE.Mesh(crustGeo, crust);
    const inner = new THREE.Mesh(breadGeo, bread.clone());
    inner.position.z = 0.0045;
    outer.castShadow = true;
    inner.castShadow = true;
    slice.add(outer, inner);
    slice.position.set(index ? 0.018 : -0.018, 0, z);
    slice.rotation.y = index ? -0.04 : 0.04;
    slice.userData.breadMaterial = inner.material;
    slice.userData.basePosition = slice.position.clone();
    slice.userData.baseRotation = slice.rotation.clone();
    toastGroup.add(slice);
  });
  toastGroup.position.set(0.012, toastBaseY, 0);
  stage.add(toastGroup);
  createParticlePools();
}

function createParticlePools() {
  const crumbGeometry = new THREE.BoxGeometry(0.0035, 0.0035, 0.0035);
  for (let index = 0; index < 28; index += 1) {
    const particle = new THREE.Mesh(
      crumbGeometry,
      new THREE.MeshStandardMaterial({ color: 0xd88934, roughness: 1, transparent: true }),
    );
    particle.visible = false;
    stage.add(particle);
    crumbParticles.push(particle);
  }

  const canvas = document.createElement('canvas');
  canvas.width = 64;
  canvas.height = 64;
  const context = canvas.getContext('2d');
  const gradient = context.createRadialGradient(32, 32, 3, 32, 32, 31);
  gradient.addColorStop(0, 'rgba(72,62,54,.52)');
  gradient.addColorStop(.45, 'rgba(96,86,76,.28)');
  gradient.addColorStop(1, 'rgba(110,100,90,0)');
  context.fillStyle = gradient;
  context.fillRect(0, 0, 64, 64);
  const smokeTexture = new THREE.CanvasTexture(canvas);
  for (let index = 0; index < 9; index += 1) {
    const particle = new THREE.Sprite(new THREE.SpriteMaterial({ map: smokeTexture, transparent: true, depthWrite: false, opacity: 0 }));
    particle.visible = false;
    stage.add(particle);
    smokeParticles.push(particle);
  }
}

function launchToast(kind) {
  if (!toastGroup) return;
  toastMotionActive = true;
  toastTarget = -0.035;
  const strength = kind === 'miss' ? 0.43 : kind === 'perfect' ? 0.39 : kind === 'golden' ? 0.36 : 0.32;
  toastGroup.children.forEach((slice, index) => {
    slice.visible = true;
    slice.userData.velocityY = strength + Math.random() * 0.035 + index * 0.025;
    slice.userData.velocityZ = (index ? 1 : -1) * (0.018 + Math.random() * 0.012);
    slice.userData.launchAge = 0;
  });
}

function resetToast() {
  if (!toastGroup) return;
  toastMotionActive = false;
  toastGroup.rotation.z = 0;
  toastGroup.children.forEach((slice) => {
    slice.visible = true;
    slice.position.copy(slice.userData.basePosition);
    slice.rotation.copy(slice.userData.baseRotation);
    slice.userData.breadMaterial.color.setRGB(0.96, 0.78, 0.44);
    slice.userData.breadMaterial.emissive.set(0x000000);
    slice.userData.breadMaterial.emissiveIntensity = 0;
  });
}

function spawnCrumbs(kind) {
  const count = kind === 'perfect' ? 24 : kind === 'miss' ? 18 : 12;
  crumbParticles.slice(0, count).forEach((particle, index) => {
    particle.visible = true;
    particle.position.set(-0.02 + Math.random() * 0.05, 0.17 + Math.random() * 0.035, (Math.random() - 0.5) * 0.09);
    particle.scale.setScalar(0.55 + Math.random() * 1.1);
    particle.material.color.set(kind === 'miss' && index % 3 === 0 ? 0x4d3528 : index % 2 ? 0xe5a248 : 0xb96b2d);
    particle.material.opacity = 1;
    particle.userData.velocity = new THREE.Vector3((Math.random() - 0.5) * 0.14, 0.15 + Math.random() * 0.38, (Math.random() - 0.5) * 0.32);
    particle.userData.spin = new THREE.Vector3(Math.random() * 8, Math.random() * 8, Math.random() * 8);
    particle.userData.life = 0.72 + Math.random() * 0.45;
  });

  if (kind === 'miss') {
    smokeParticles.forEach((particle, index) => {
      particle.visible = true;
      particle.position.set(-0.01, 0.19 + index * 0.004, (Math.random() - 0.5) * 0.055);
      particle.scale.setScalar(0.015 + Math.random() * 0.012);
      particle.material.opacity = 0.42;
      particle.userData.velocity = new THREE.Vector3((Math.random() - 0.5) * 0.018, 0.035 + Math.random() * 0.035, (Math.random() - 0.5) * 0.025);
      particle.userData.life = 1 + Math.random() * 0.7;
    });
  }
}

function updateParticles(delta) {
  crumbParticles.forEach((particle) => {
    if (!particle.visible) return;
    particle.userData.life -= delta;
    particle.userData.velocity.y -= 0.72 * delta;
    particle.position.addScaledVector(particle.userData.velocity, delta);
    particle.rotation.x += particle.userData.spin.x * delta;
    particle.rotation.y += particle.userData.spin.y * delta;
    particle.rotation.z += particle.userData.spin.z * delta;
    particle.material.opacity = clamp(particle.userData.life * 2, 0, 1);
    if (particle.userData.life <= 0) particle.visible = false;
  });
  smokeParticles.forEach((particle) => {
    if (!particle.visible) return;
    particle.userData.life -= delta;
    particle.position.addScaledVector(particle.userData.velocity, delta);
    particle.scale.multiplyScalar(1 + delta * 0.72);
    particle.material.opacity = clamp(particle.userData.life * 0.28, 0, 0.38);
    if (particle.userData.life <= 0) particle.visible = false;
  });
}

function updateToastMotion(delta) {
  if (!toastMotionActive || !toastGroup) return;
  let moving = false;
  toastGroup.children.forEach((slice) => {
    if (!slice.visible) return;
    slice.userData.launchAge += delta;
    slice.userData.velocityY += 0.62 * delta;
    slice.position.y += slice.userData.velocityY * delta;
    slice.position.z += slice.userData.velocityZ * delta;
    slice.rotation.x = THREE.MathUtils.lerp(slice.rotation.x, slice.userData.baseRotation.x, Math.min(delta * 12, 1));
    slice.rotation.y = THREE.MathUtils.lerp(slice.rotation.y, slice.userData.baseRotation.y, Math.min(delta * 12, 1));
    slice.rotation.z = slice.userData.baseRotation.z + Math.sin(slice.userData.launchAge * 8 + (slice.position.z > 0 ? 1 : 0)) * 0.025;

    const worldPosition = new THREE.Vector3();
    slice.getWorldPosition(worldPosition);
    worldPosition.project(camera);
    if (worldPosition.y > 1.28) {
      slice.visible = false;
    } else {
      moving = true;
    }
  });
  toastMotionActive = moving;
}

function prepareKnob(mesh) {
  mesh.geometry = mesh.geometry.clone();
  mesh.geometry.computeBoundingBox();
  const center = new THREE.Vector3();
  mesh.geometry.boundingBox.getCenter(center);
  mesh.geometry.translate(-center.x, -center.y, -center.z);
  mesh.position.copy(center);

  const marker = new THREE.Mesh(
    new THREE.BoxGeometry(0.0015, 0.0024, 0.008),
    new THREE.MeshBasicMaterial({ color: 0xffe3a1 }),
  );
  marker.position.set(-0.0133, 0, 0.008);
  mesh.add(marker);
}

const loader = new GLTFLoader();
loader.load(toasterUrl, (gltf) => {
  toaster = gltf.scene;
  toaster.traverse((child) => {
    if (!child.isMesh) return;
    child.castShadow = true;
    child.receiveShadow = true;
    if (child.material) {
      child.material = child.material.clone();
      child.material.roughness = Math.max(child.material.roughness ?? 0.5, 0.42);
      child.material.metalness = Math.min(child.material.metalness ?? 0, 0.72);
      child.material.needsUpdate = true;
    }
    if (child.name === 'scroll_button_mesh') leverParts.push(child);
    if (child.name === 'button_002_mesh') {
      buttonBankMesh = child;
      const positions = child.geometry.getAttribute('position');
      buttonBankBasePositions = Float32Array.from(positions.array);
      leverInsertVertexIndices = [];
      for (let index = 0; index < positions.count; index += 1) {
        const z = positions.getZ(index);
        const y = positions.getY(index);
        if (z > -0.02) {
          leverInsertVertexIndices.push(index);
        } else if (y > 0.106) {
          buttonVertexIndices.sound.push(index);
        } else if (y > 0.091) {
          buttonVertexIndices.haptics.push(index);
        } else if (y > 0.076) {
          buttonVertexIndices.settings.push(index);
        } else {
          buttonVertexIndices.ranks.push(index);
        }
      }
    }
    if (child.name === 'rotate_button_mesh') {
      knobMesh = child;
      prepareKnob(knobMesh);
    }
    if (child.name.includes('heater_002')) heaterMeshes.push(child);
  });
  toaster.rotation.y = -THREE.MathUtils.degToRad(7);
  stage.add(toaster);
  createToast();
  syncControlMaterials();
  setDifficulty(game.mode, false);
  game.state = 'ready';
  ui.status.querySelector('span').textContent = 'READY';
  ui.leverHitbox.classList.add('is-ready');
  ui.leverGuide.classList.add('is-ready');
  ui.toasterMenu.classList.add('is-ready');
  ui.toasterMenu.inert = false;
  ui.toasterMenu.setAttribute('aria-hidden', 'false');
  updateControlScreenPositions();
  ui.loadingBar.style.width = '100%';
  setTimeout(() => ui.loadingScreen.classList.add('is-hidden'), 260);
}, (event) => {
  if (event.lengthComputable) ui.loadingBar.style.width = `${Math.max(12, event.loaded / event.total * 100)}%`;
}, () => {
  ui.headline.textContent = 'Toaster missing';
  ui.subcopy.textContent = 'Pop toaster.glb into the project root and reload.';
  ui.loadingScreen.querySelector('strong').textContent = 'COULDN’T WARM UP';
  ui.loadingBar.style.width = '100%';
});

function setLever(progress) {
  game.leverProgress = clamp(progress, 0, 1);
  const offset = -0.054 * game.leverProgress;
  leverParts.forEach((part) => { part.position.y = offset; });
  updateButtonBankGeometry();
  updateLeverScreenPosition();
}

function updateButtonBankGeometry() {
  if (buttonBankMesh && buttonBankBasePositions) {
    const positions = buttonBankMesh.geometry.getAttribute('position');
    leverInsertVertexIndices.forEach((index) => {
      positions.setY(index, buttonBankBasePositions[index * 3 + 1] - 0.054 * game.leverProgress);
    });
    Object.entries(buttonVertexIndices).forEach(([kind, indices]) => {
      indices.forEach((index) => {
        positions.setX(index, buttonBankBasePositions[index * 3] + buttonPresses[kind].depth);
      });
    });
    positions.needsUpdate = true;
  }
}

function updateLeverScreenPosition() {
  if (!toaster || !leverParts.length) return;
  const rect = ui.game.getBoundingClientRect();
  const point = new THREE.Vector3(-0.118, 0.117 - 0.054 * game.leverProgress, 0.012);
  toaster.localToWorld(point);
  point.project(camera);
  const x = (point.x * 0.5 + 0.5) * rect.width;
  const y = (-point.y * 0.5 + 0.5) * rect.height;
  ui.leverHitbox.style.left = `${x}px`;
  ui.leverHitbox.style.top = `${y}px`;
  ui.leverGuide.style.left = `${x}px`;
  ui.leverGuide.style.top = `${y}px`;
}

function projectToScreen(point) {
  const rect = ui.game.getBoundingClientRect();
  point.project(camera);
  return {
    x: (point.x * 0.5 + 0.5) * rect.width,
    y: (-point.y * 0.5 + 0.5) * rect.height,
  };
}

function updateControlScreenPositions() {
  updateLeverScreenPosition();
  if (!toaster || !buttonBankMesh || !knobMesh) return;
  const elements = {
    sound: ui.frontSound,
    haptics: ui.frontHaptics,
    settings: ui.frontSettings,
    ranks: ui.frontRanks,
  };
  Object.entries(elements).forEach(([kind, element]) => {
    const point = controlPoints[kind].clone();
    buttonBankMesh.localToWorld(point);
    const projected = projectToScreen(point);
    projectedControls[kind] = projected;
    element.style.left = `${projected.x}px`;
    element.style.top = `${projected.y}px`;
  });
  const buttonPositions = Object.values(projectedControls);
  const top = Math.min(...buttonPositions.map((position) => position.y));
  const bottom = Math.max(...buttonPositions.map((position) => position.y));
  const averageX = buttonPositions.reduce((total, position) => total + position.x, 0) / buttonPositions.length;
  ui.buttonBankHitbox.style.left = `${averageX}px`;
  ui.buttonBankHitbox.style.top = `${(top + bottom) / 2}px`;
  ui.buttonBankHitbox.style.height = `${Math.max(72, bottom - top + 34)}px`;

  const knobPoint = new THREE.Vector3();
  knobMesh.getWorldPosition(knobPoint);
  const knobPosition = projectToScreen(knobPoint.clone());
  ui.knobHitbox.style.left = `${knobPosition.x}px`;
  ui.knobHitbox.style.top = `${knobPosition.y}px`;
  ui.difficultyReadout.style.left = `${knobPosition.x}px`;
  ui.difficultyReadout.style.top = `${knobPosition.y - 59}px`;
  ui.knobGuide.style.left = `${knobPosition.x}px`;
  ui.knobGuide.style.top = `${knobPosition.y + 53}px`;
}

function syncControlMaterials() {
  ui.frontSound.dataset.label = game.muted ? 'SOUND OFF' : 'SOUND';
  ui.frontHaptics.dataset.label = game.haptics ? 'HAPTIC' : 'HAPTIC OFF';
  ui.frontSound.setAttribute('aria-label', game.muted ? 'Turn sound on' : 'Mute sound');
  ui.frontHaptics.setAttribute('aria-label', game.haptics ? 'Turn haptics off' : 'Turn haptics on');
  ui.frontSound.setAttribute('aria-pressed', String(game.muted));
  ui.frontHaptics.setAttribute('aria-pressed', String(game.haptics));
  ui.settingsSound.setAttribute('aria-pressed', String(!game.muted));
  ui.settingsHaptics.setAttribute('aria-pressed', String(game.haptics));
  ui.settingsSound.textContent = game.muted ? 'OFF' : 'ON';
  ui.settingsSound.classList.toggle('is-off', game.muted);
  ui.settingsHaptics.textContent = game.haptics ? 'ON' : 'OFF';
  ui.settingsHaptics.classList.toggle('is-off', !game.haptics);
}

function setDifficulty(mode, withFeedback = true) {
  if (!modes[mode]) return;
  game.mode = mode;
  writeSetting('toastyy-mode', game.mode);
  const index = modeOrder.indexOf(mode);
  knobTargetAngle = [-0.86, -0.29, 0.29, 0.86][index];
  ui.difficultyName.textContent = modes[mode].label;
  ui.modeChip.textContent = `${modes[mode].label} · ${modes[mode].multiplier.toFixed(1)}×`;
  ui.knobHitbox.setAttribute('aria-label', `Turn difficulty knob. Current difficulty: ${modes[mode].label}`);
  ui.knobHitbox.setAttribute('aria-valuenow', String(index + 1));
  ui.knobHitbox.setAttribute('aria-valuetext', modes[mode].label);
  ui.difficultyReadout.classList.remove('is-changing');
  void ui.difficultyReadout.offsetWidth;
  ui.difficultyReadout.classList.add('is-changing');
  if (withFeedback) {
    playClick(150 + index * 55, 0.055);
    buzz(12);
  }
}

let scoreAnimation;
function animateScore(from, to) {
  scoreAnimation = { from, to, start: performance.now(), duration: 520 };
  ui.score.classList.remove('is-punch');
  void ui.score.offsetWidth;
  ui.score.classList.add('is-punch');
}

function showScoreReaction(points) {
  ui.scoreFly.textContent = `+${points}`;
  ui.scoreFly.classList.remove('is-visible');
  void ui.scoreFly.offsetWidth;
  ui.scoreFly.classList.add('is-visible');
  if (game.streak > 1) {
    ui.comboBadge.querySelector('strong').textContent = `×${game.streak}`;
    ui.comboBadge.classList.remove('is-visible');
    void ui.comboBadge.offsetWidth;
    ui.comboBadge.classList.add('is-visible');
  }
  ui.streakWrap.classList.toggle('is-hot', game.streak >= 3);
  ui.streakWrap.classList.remove('is-punch');
  void ui.streakWrap.offsetWidth;
  ui.streakWrap.classList.add('is-punch');
}

function setStatus(label, className = '') {
  ui.status.className = `status-pill ${className}`.trim();
  ui.status.querySelector('span').textContent = label;
}

function setCopy(eyebrow, headline, subcopy) {
  ui.eyebrow.textContent = eyebrow;
  ui.headline.textContent = headline;
  ui.subcopy.textContent = subcopy;
}

function startRound() {
  if (game.state !== 'ready') return;
  leverReturnStart = 0;
  game.state = 'toasting';
  latchKick = 1;
  presentationTarget = 1;
  game.round += 1;
  game.roundStart = performance.now();
  const mode = modes[game.mode];
  const difficulty = Math.min((game.round - 1) * 0.025, 0.18);
  game.popAt = mode.min + Math.random() * mode.range;
  game.popAt *= 1 - difficulty;
  game.dangerAt = game.popAt - 720;
  game.nextTickAt = game.roundStart + 620;
  game.dangerBuzzed = false;
  toastTarget = -0.035;
  ui.leverHitbox.disabled = true;
  ui.leverGuide.classList.add('is-hidden');
  ui.toasterMenu.inert = true;
  ui.toasterMenu.setAttribute('aria-hidden', 'true');
  ui.stopButton.disabled = false;
  ui.stopButton.classList.add('is-visible');
  ui.heatLines.classList.add('is-visible');
  ui.heatMeter.classList.add('is-visible');
  ui.resultCard.className = 'result-card';
  ui.resultCard.setAttribute('aria-hidden', 'true');
  ui.toasterMenu.classList.add('is-hidden');
  ui.helpButton.disabled = true;
  setStatus('TOASTING', 'is-hot');
  setCopy(`${mode.label} · ROUND ${game.round}`, 'Listen closely…', 'Tap anywhere as late as you dare.');
  playLatch();
  startHum();
  buzz(25);
}

function stopRound() {
  if (game.state !== 'toasting') return;
  const elapsed = performance.now() - game.roundStart;
  if (elapsed >= game.popAt) {
    missRound();
    return;
  }
  const remaining = Math.max(0, game.popAt - elapsed);
  const progress = clamp(elapsed / game.popAt, 0, 1);
  const timingScore = Math.round(1000 * Math.pow(1 - remaining / game.popAt, 3));
  const streakBoost = Math.min(game.streak * 25, 250);
  const points = Math.max(35, Math.round((timingScore + streakBoost) * modes[game.mode].multiplier));
  let rating = 'TOO EARLY';
  if (remaining < 150) rating = 'PERFECT!';
  else if (progress > 0.9) rating = 'GOLDEN!';
  else if (progress > 0.74) rating = 'NICE SAVE';
  else if (progress > 0.5) rating = 'A LITTLE PALE';

  game.state = 'result';
  const oldScore = game.score;
  const previousBest = game.best;
  game.score += points;
  game.streak += 1;
  game.best = Math.max(game.best, game.score);
  game.bestStreak = Math.max(game.bestStreak, game.streak);
  if (rating === 'PERFECT!') game.perfects += 1;
  writeSetting('toastyy-best', game.best);
  writeSetting('toastyy-best-streak', game.bestStreak);
  writeSetting('toastyy-perfects', game.perfects);
  animateScore(oldScore, game.score);
  ui.best.textContent = formatScore(game.best);
  ui.best.classList.toggle('is-best', game.best > previousBest);
  ui.streak.textContent = game.streak;
  showScoreReaction(points);
  ui.stopButton.disabled = true;
  ui.stopButton.classList.remove('is-visible');
  ui.stopButton.classList.remove('is-danger');
  ui.heatLines.classList.remove('is-visible');
  ui.heatMeter.classList.remove('is-visible');
  ui.resultKicker.textContent = rating;
  ui.resultPoints.textContent = `+${points}`;
  ui.resultTiming.textContent = `${(remaining / 1000).toFixed(2)}s to spare`;
  const resultKind = rating === 'PERFECT!' ? 'perfect' : rating === 'GOLDEN!' ? 'golden' : 'early';
  ui.resultCard.className = `result-card is-visible ${rating === 'PERFECT!' ? 'is-perfect' : ''} ${game.best > previousBest ? 'is-new-best' : ''}`.trim();
  ui.resultCard.setAttribute('aria-hidden', 'false');
  if (rating === 'PERFECT!') {
    toastGroup?.children.forEach((slice) => {
      slice.userData.breadMaterial.emissive.set(0xff7b20);
      slice.userData.breadMaterial.emissiveIntensity = 0.28;
    });
  }
  launchToast(resultKind);
  spawnCrumbs(resultKind);
  if (rating === 'PERFECT!') {
    ui.game.classList.remove('is-perfect-flash');
    void ui.game.offsetWidth;
    ui.game.classList.add('is-perfect-flash');
  }
  animateLeverBack(70);
  setStatus('SAVED');
  setCopy('ROUND COMPLETE', rating === 'PERFECT!' ? 'Chef’s kiss.' : 'Still edible.', 'Your next slice is almost ready.');
  stopHum();
  playSuccess(rating === 'PERFECT!');
  buzz(rating === 'PERFECT!' ? [20, 35, 35] : 25);
  game.resetAt = performance.now() + (rating === 'PERFECT!' ? 2250 : 1850);
}

function missRound() {
  if (game.state !== 'toasting') return;
  game.state = 'result';
  game.pendingRunReset = true;
  game.streak = 0;
  ui.streak.textContent = '0';
  ui.streakWrap.classList.remove('is-hot');
  ui.stopButton.disabled = true;
  ui.stopButton.classList.remove('is-visible');
  ui.stopButton.classList.remove('is-danger');
  ui.heatLines.classList.remove('is-visible');
  ui.heatMeter.classList.remove('is-visible');
  ui.resultKicker.textContent = 'TOO LATE!';
  ui.resultPoints.textContent = 'BURNT';
  ui.resultTiming.textContent = game.score ? `run score ${formatScore(game.score)}` : 'the toaster got you';
  ui.resultCard.className = 'result-card is-visible is-miss';
  ui.resultCard.setAttribute('aria-hidden', 'false');
  ui.game.classList.remove('is-shaking', 'is-flashing');
  void ui.game.offsetWidth;
  ui.game.classList.add('is-shaking', 'is-flashing');
  toastGroup?.children.forEach((slice) => slice.userData.breadMaterial.color.multiplyScalar(0.42));
  launchToast('miss');
  spawnCrumbs('miss');
  animateLeverBack(40);
  setStatus('POPPED', 'is-missed');
  setCopy('ROUND OVER', 'Too slow!', 'Cooling down for another run.');
  stopHum();
  playMiss();
  buzz([70, 35, 90]);
  game.resetAt = performance.now() + 2200;
}

function resetRound() {
  game.state = 'ready';
  presentationTarget = 0;
  game.resetAt = 0;
  if (game.pendingRunReset) {
    game.pendingRunReset = false;
    game.score = 0;
    game.displayScore = 0;
    game.round = 0;
    scoreAnimation = undefined;
    ui.score.textContent = '0000';
    ui.score.classList.remove('is-punch');
  }
  ui.resultCard.className = 'result-card';
  ui.resultCard.setAttribute('aria-hidden', 'true');
  ui.leverHitbox.disabled = false;
  ui.leverGuide.classList.remove('is-hidden');
  ui.toasterMenu.classList.remove('is-hidden');
  ui.toasterMenu.inert = false;
  ui.toasterMenu.setAttribute('aria-hidden', 'false');
  ui.helpButton.disabled = false;
  leverReturnStart = 0;
  setLever(0);
  toastTarget = 0;
  resetToast();
  visualHeat = 0;
  visualDanger = 0;
  ui.app.style.setProperty('--heat', '0');
  ui.app.style.setProperty('--danger', '0');
  ui.app.style.setProperty('--heat-opacity', '0');
  ui.app.style.setProperty('--heat-scale', '.7');
  ui.app.style.setProperty('--danger-opacity', '0');
  ui.app.style.setProperty('--steam-duration', '1.2s');
  ui.game.classList.remove('is-danger', 'is-shaking', 'is-flashing', 'is-perfect-flash');
  ui.best.classList.remove('is-best');
  setStatus('READY');
  setCopy(game.round ? 'SET UP THE NEXT SLICE' : 'YOUR TOASTER, YOUR RULES', 'Set it. Pull it.', 'Turn the knob for difficulty, then pull the lever.');
}

function startDrag(event) {
  if (game.state !== 'ready') return;
  leverReturnStart = 0;
  game.dragging = true;
  game.dragStartY = event.clientY;
  game.dragStartProgress = game.leverProgress;
  game.leverNotch = Math.floor(game.leverProgress * 4);
  ui.leverHitbox.setPointerCapture(event.pointerId);
  playClick(72, 0.025);
}

function moveDrag(event) {
  if (!game.dragging) return;
  const distance = event.clientY - game.dragStartY;
  const rawProgress = game.dragStartProgress + distance / 72;
  const resistedProgress = rawProgress <= 0.82 ? rawProgress : 0.82 + (rawProgress - 0.82) * 0.82;
  setLever(resistedProgress);
  const notch = Math.floor(game.leverProgress * 4);
  if (notch > game.leverNotch && notch < 4) {
    game.leverNotch = notch;
    playClick(70 + notch * 12, 0.022);
    buzz(6);
  }
  if (game.leverProgress >= 0.98) {
    game.dragging = false;
    setLever(1);
    if (ui.leverHitbox.hasPointerCapture(event.pointerId)) ui.leverHitbox.releasePointerCapture(event.pointerId);
    startRound();
  }
}

function endDrag(event) {
  if (!game.dragging) return;
  game.dragging = false;
  if (ui.leverHitbox.hasPointerCapture(event.pointerId)) ui.leverHitbox.releasePointerCapture(event.pointerId);
  if (game.leverProgress < 0.98) animateLeverBack();
}

let leverReturnStart = 0;
let leverReturnFrom = 0;
function animateLeverBack(delay = 0) {
  leverReturnStart = performance.now() + delay;
  leverReturnFrom = game.leverProgress;
}

ui.leverHitbox.addEventListener('pointerdown', startDrag);
ui.leverHitbox.addEventListener('pointermove', moveDrag);
ui.leverHitbox.addEventListener('pointerup', endDrag);
ui.leverHitbox.addEventListener('pointercancel', endDrag);
ui.leverHitbox.addEventListener('click', (event) => {
  if (event.detail === 0 && game.state === 'ready') {
    setLever(1);
    startRound();
  }
});

ui.stopButton.addEventListener('pointerdown', (event) => event.stopPropagation());
ui.stopButton.addEventListener('click', stopRound);
ui.game.addEventListener('pointerdown', (event) => {
  if (event.target === ui.leverHitbox || event.target.closest('.stop-button')) return;
  if (game.state === 'toasting') stopRound();
});

window.addEventListener('keydown', (event) => {
  if (event.code !== 'Space' || ui.helpDialog.open || ui.ranksDialog.open) return;
  if (event.target.closest?.('button, a, input, select, textarea, dialog, [contenteditable="true"]')) return;
  event.preventDefault();
  if (game.state === 'ready') {
    setLever(1);
    startRound();
  } else if (game.state === 'toasting') stopRound();
});

function toggleSound() {
  game.muted = !game.muted;
  writeSetting('toastyy-muted', game.muted);
  ui.soundButton.setAttribute('aria-pressed', String(game.muted));
  ui.soundButton.setAttribute('aria-label', game.muted ? 'Turn sound on' : 'Mute sound');
  syncControlMaterials();
  if (game.muted) {
    stopHum();
  } else {
    playClick(260, 0.06);
    if (game.state === 'toasting') startHum();
  }
}

function toggleHaptics() {
  game.haptics = !game.haptics;
  writeSetting('toastyy-haptics', game.haptics);
  syncControlMaterials();
  if (game.haptics) buzz([12, 24, 12]);
  playClick(game.haptics ? 230 : 120, 0.05);
}

function pressPhysicalButton(kind) {
  const element = {
    sound: ui.frontSound,
    haptics: ui.frontHaptics,
    settings: ui.frontSettings,
    ranks: ui.frontRanks,
  }[kind];
  buttonPresses[kind].target = 0.0024;
  element.classList.add('is-pressed');
  setTimeout(() => {
    buttonPresses[kind].target = 0;
    element.classList.remove('is-pressed');
  }, 105);
}

function openSettings() {
  if (game.state !== 'ready') return;
  syncControlMaterials();
  ui.helpDialog.showModal();
}

function openRanks() {
  if (game.state !== 'ready') return;
  ui.rankBest.textContent = formatScore(game.best);
  ui.rankStreak.textContent = game.bestStreak;
  ui.rankPerfects.textContent = game.perfects;
  ui.ranksDialog.showModal();
}

ui.soundButton.addEventListener('click', toggleSound);
ui.frontSound.addEventListener('click', () => { pressPhysicalButton('sound'); toggleSound(); });
ui.frontHaptics.addEventListener('click', () => { pressPhysicalButton('haptics'); toggleHaptics(); });
ui.frontSettings.addEventListener('click', () => { pressPhysicalButton('settings'); playClick(205, 0.045); openSettings(); });
ui.frontRanks.addEventListener('click', () => { pressPhysicalButton('ranks'); playClick(280, 0.045); openRanks(); });
ui.buttonBankHitbox.addEventListener('pointerdown', (event) => {
  if (game.state !== 'ready') return;
  event.preventDefault();
  event.stopPropagation();
  const localY = event.clientY - ui.game.getBoundingClientRect().top;
  const kind = Object.keys(projectedControls).reduce((closest, candidate) => (
    Math.abs(projectedControls[candidate].y - localY) < Math.abs(projectedControls[closest].y - localY) ? candidate : closest
  ), 'sound');
  ({ sound: ui.frontSound, haptics: ui.frontHaptics, settings: ui.frontSettings, ranks: ui.frontRanks })[kind].click();
});

ui.knobHitbox.addEventListener('pointerdown', (event) => {
  if (game.state !== 'ready') return;
  game.knobDragging = true;
  game.knobMoved = false;
  game.knobStartX = event.clientX;
  game.knobStartIndex = modeOrder.indexOf(game.mode);
  ui.knobHitbox.setPointerCapture(event.pointerId);
});

ui.knobHitbox.addEventListener('pointermove', (event) => {
  if (!game.knobDragging) return;
  const distance = event.clientX - game.knobStartX;
  if (Math.abs(distance) > 6) game.knobMoved = true;
  const nextIndex = clamp(game.knobStartIndex + Math.round(distance / 30), 0, modeOrder.length - 1);
  if (modeOrder[nextIndex] !== game.mode) setDifficulty(modeOrder[nextIndex]);
});

function endKnobDrag(event) {
  if (!game.knobDragging) return;
  game.knobDragging = false;
  if (ui.knobHitbox.hasPointerCapture(event.pointerId)) ui.knobHitbox.releasePointerCapture(event.pointerId);
  if (!game.knobMoved) {
    const nextIndex = (modeOrder.indexOf(game.mode) + 1) % modeOrder.length;
    setDifficulty(modeOrder[nextIndex]);
  }
}

ui.knobHitbox.addEventListener('pointerup', endKnobDrag);
ui.knobHitbox.addEventListener('pointercancel', (event) => {
  game.knobDragging = false;
  if (ui.knobHitbox.hasPointerCapture(event.pointerId)) ui.knobHitbox.releasePointerCapture(event.pointerId);
});
ui.knobHitbox.addEventListener('click', (event) => {
  if (event.detail !== 0 || game.state !== 'ready') return;
  const nextIndex = (modeOrder.indexOf(game.mode) + 1) % modeOrder.length;
  setDifficulty(modeOrder[nextIndex]);
});
ui.knobHitbox.addEventListener('keydown', (event) => {
  if (game.state !== 'ready' || !['ArrowLeft', 'ArrowRight', 'ArrowUp', 'ArrowDown', 'Home', 'End'].includes(event.key)) return;
  event.preventDefault();
  const current = modeOrder.indexOf(game.mode);
  let next = current;
  if (event.key === 'ArrowRight' || event.key === 'ArrowUp') next += 1;
  if (event.key === 'ArrowLeft' || event.key === 'ArrowDown') next -= 1;
  if (event.key === 'Home') next = 0;
  if (event.key === 'End') next = modeOrder.length - 1;
  setDifficulty(modeOrder[clamp(next, 0, modeOrder.length - 1)]);
});

ui.helpButton.addEventListener('click', openSettings);
ui.dialogClose.addEventListener('click', () => ui.helpDialog.close());
ui.dialogOk.addEventListener('click', () => ui.helpDialog.close());
ui.settingsSound.addEventListener('click', toggleSound);
ui.settingsHaptics.addEventListener('click', toggleHaptics);
ui.ranksClose.addEventListener('click', () => ui.ranksDialog.close());
ui.ranksOk.addEventListener('click', () => ui.ranksDialog.close());

let audioContext;
let humOscillator;
let humGain;
function buzz(pattern) {
  if (game.haptics && navigator.vibrate) navigator.vibrate(pattern);
}

function getAudioContext() {
  if (game.muted) return undefined;
  try {
    audioContext ||= new AudioContext();
    if (audioContext.state === 'suspended') audioContext.resume();
    return audioContext;
  } catch {
    return undefined;
  }
}

function tone(frequency, duration, type = 'sine', volume = 0.06, delay = 0) {
  const context = getAudioContext();
  if (!context) return;
  const oscillator = context.createOscillator();
  const gain = context.createGain();
  const start = context.currentTime + delay;
  oscillator.type = type;
  oscillator.frequency.setValueAtTime(frequency, start);
  gain.gain.setValueAtTime(0.0001, start);
  gain.gain.exponentialRampToValueAtTime(volume, start + 0.012);
  gain.gain.exponentialRampToValueAtTime(0.0001, start + duration);
  oscillator.connect(gain).connect(context.destination);
  oscillator.start(start);
  oscillator.stop(start + duration + 0.02);
}

function playClick(frequency, duration) { tone(frequency, duration, 'triangle', 0.075); }
function playLatch() {
  tone(82, 0.08, 'square', 0.045);
  tone(48, 0.13, 'triangle', 0.08, 0.045);
  tone(180, 0.04, 'square', 0.025, 0.085);
}
function playThermalTick(intensity) {
  tone(650 + intensity * 520 + Math.random() * 120, 0.025, 'square', 0.012 + intensity * 0.014);
}
function startHum() {
  if (humOscillator || game.muted) return;
  const context = getAudioContext();
  if (!context) return;
  humOscillator = context.createOscillator();
  humGain = context.createGain();
  humOscillator.type = 'sine';
  humOscillator.frequency.setValueAtTime(54, context.currentTime);
  humGain.gain.setValueAtTime(0.0001, context.currentTime);
  humGain.gain.exponentialRampToValueAtTime(0.018, context.currentTime + 0.18);
  humOscillator.connect(humGain).connect(context.destination);
  humOscillator.start();
}
function updateHum(heat, danger) {
  if (!humOscillator || !humGain || !audioContext) return;
  humOscillator.frequency.setTargetAtTime(54 + heat * 36 + danger * 34, audioContext.currentTime, 0.08);
  humGain.gain.setTargetAtTime(0.012 + heat * 0.012 + danger * 0.018, audioContext.currentTime, 0.1);
}
function stopHum() {
  if (!humOscillator || !humGain || !audioContext) return;
  const oscillator = humOscillator;
  const gain = humGain;
  humOscillator = undefined;
  humGain = undefined;
  gain.gain.cancelScheduledValues(audioContext.currentTime);
  gain.gain.setTargetAtTime(0.0001, audioContext.currentTime, 0.045);
  oscillator.stop(audioContext.currentTime + 0.24);
}
function playSuccess(perfect) {
  tone(perfect ? 440 : 350, 0.14, 'sine', 0.055);
  tone(perfect ? 660 : 520, 0.22, 'sine', 0.055, 0.095);
  if (perfect) tone(880, 0.28, 'sine', 0.045, 0.19);
}
function playMiss() {
  tone(125, 0.25, 'sawtooth', 0.045);
  tone(82, 0.32, 'sawtooth', 0.035, 0.12);
  tone(48, 0.12, 'square', 0.055, 0.02);
}

function resize() {
  const rect = ui.game.getBoundingClientRect();
  renderer.setSize(rect.width, rect.height, false);
  camera.aspect = rect.width / Math.max(rect.height, 1);
  const portrait = camera.aspect < 0.85;
  camera.fov = portrait ? (rect.height < 520 ? 31 : 28) : 23;
  camera.position.set(portrait ? -0.68 : -0.74, portrait ? 0.26 : 0.245, 0);
  camera.lookAt(0, 0.085, 0);
  camera.updateProjectionMatrix();
  updateControlScreenPositions();
}

const resizeObserver = new ResizeObserver(resize);
resizeObserver.observe(ui.game);

document.addEventListener('visibilitychange', () => {
  const now = performance.now();
  if (document.hidden) {
    game.hiddenAt = now;
    if (audioContext?.state === 'running') audioContext.suspend();
    return;
  }
  if (!game.hiddenAt) return;
  const pausedFor = now - game.hiddenAt;
  if (game.state === 'toasting') {
    game.roundStart += pausedFor;
    game.nextTickAt += pausedFor;
    if (!game.muted) audioContext?.resume();
  }
  if (game.state === 'result' && game.resetAt) game.resetAt += pausedFor;
  if (leverReturnStart) leverReturnStart += pausedFor;
  game.hiddenAt = 0;
});

let previous = performance.now();
let lastControlProjection = 0;
function render(now) {
  requestAnimationFrame(render);
  const delta = Math.min((now - previous) / 1000, 0.05);
  previous = now;

  const previousPresentation = presentation;
  if (reducedMotion.matches) {
    presentation = presentationTarget;
  } else {
    const poseDamping = 1 - Math.exp(-delta * 4.4);
    presentation += (presentationTarget - presentation) * poseDamping;
    if (Math.abs(presentationTarget - presentation) < 0.0005) presentation = presentationTarget;
  }
  const pose = presentation * presentation * (3 - 2 * presentation);
  stage.rotation.y = THREE.MathUtils.lerp(0, 0.26, pose);
  stage.scale.setScalar(THREE.MathUtils.lerp(1, 1.09, pose));
  stage.position.x = THREE.MathUtils.lerp(0.012, 0.006, pose);
  latchKick *= Math.exp(-delta * 10);
  stage.position.y = THREE.MathUtils.lerp(-0.02, -0.024, pose) - latchKick * 0.0028;
  shadow.material.opacity = THREE.MathUtils.lerp(0.42, 0.54, pose);
  if (presentation !== previousPresentation) updateLeverScreenPosition();

  if (leverReturnStart && !game.dragging) {
    const progress = clamp((now - leverReturnStart) / 330, 0, 1);
    if (now >= leverReturnStart) setLever(leverReturnFrom * (1 - easeOutBack(progress)));
    if (progress >= 1) leverReturnStart = 0;
  }

  if (game.state === 'toasting') {
    const elapsed = now - game.roundStart;
    if (elapsed >= game.popAt) {
      missRound();
      renderer.render(scene, camera);
      return;
    }
    const heat = clamp(elapsed / game.popAt, 0, 1);
    const danger = clamp((elapsed - game.dangerAt) / Math.max(game.popAt - game.dangerAt, 1), 0, 1);
    visualHeat += (heat - visualHeat) * Math.min(delta * 7, 1);
    visualDanger += (danger - visualDanger) * Math.min(delta * 9, 1);
    const litSegments = Math.min(5, Math.ceil(heat * 5));
    ui.heatSegments.forEach((segment, index) => segment.classList.toggle('is-lit', index < litSegments));
    ui.stopButton.classList.toggle('is-danger', danger > 0.22);
    if (danger > 0 && !ui.status.classList.contains('is-danger')) setStatus('ALMOST', 'is-hot is-danger');
    if (danger > 0.42 && !game.dangerBuzzed) {
      game.dangerBuzzed = true;
      buzz(18);
    }
    if (now >= game.nextTickAt) {
      playThermalTick(danger);
      game.nextTickAt = now + THREE.MathUtils.lerp(610, 115, Math.max(heat, danger));
    }
    updateHum(heat, danger);
    heaterMeshes.forEach((mesh) => {
      if (mesh.material?.emissive) {
        mesh.material.emissive.setRGB(0.8 * heat, 0.09 * heat, 0.015 * heat);
        mesh.material.emissiveIntensity = 1.5 * heat + danger * 1.2;
      }
    });
    if (toastGroup) {
      toastGroup.children.forEach((slice) => {
        const material = slice.userData.breadMaterial;
        if (material) material.color.setRGB(0.96 - heat * 0.28, 0.71 - heat * 0.29, 0.34 - heat * 0.19);
      });
      if (!reducedMotion.matches) toastGroup.rotation.z = Math.sin(now * (0.01 + danger * 0.025)) * heat * (0.009 + danger * 0.012);
    }
  } else {
    visualHeat += (0 - visualHeat) * Math.min(delta * 2.8, 1);
    visualDanger += (0 - visualDanger) * Math.min(delta * 5, 1);
    heaterMeshes.forEach((mesh) => {
      if (mesh.material?.emissive) mesh.material.emissiveIntensity = Math.max(0, mesh.material.emissiveIntensity - delta * 2.5);
    });
  }

  ui.app.style.setProperty('--heat', visualHeat.toFixed(3));
  ui.app.style.setProperty('--danger', visualDanger.toFixed(3));
  ui.app.style.setProperty('--heat-opacity', (visualHeat * 0.82).toFixed(3));
  ui.app.style.setProperty('--heat-scale', (0.7 + visualHeat * 0.35).toFixed(3));
  ui.app.style.setProperty('--danger-opacity', (visualDanger * 0.72).toFixed(3));
  ui.app.style.setProperty('--steam-duration', `${(1.2 - visualDanger * 0.72).toFixed(3)}s`);
  heaterLight.intensity = visualHeat * 2.2 + visualDanger * 3.8;

  if (game.state === 'result' && game.resetAt && now >= game.resetAt) resetRound();

  toastPop += (toastTarget - toastPop) * Math.min(delta * 11, 1);
  if (toastGroup) toastGroup.position.y = toastBaseY + toastPop;
  updateToastMotion(delta);
  updateParticles(delta);

  if (scoreAnimation) {
    const progress = clamp((now - scoreAnimation.start) / scoreAnimation.duration, 0, 1);
    const eased = 1 - Math.pow(1 - progress, 3);
    game.displayScore = Math.round(THREE.MathUtils.lerp(scoreAnimation.from, scoreAnimation.to, eased));
    ui.score.textContent = formatScore(game.displayScore);
    if (progress >= 1) scoreAnimation = undefined;
  }

  let buttonGeometryChanged = false;
  Object.values(buttonPresses).forEach((press) => {
    const previousDepth = press.depth;
    press.depth += (press.target - press.depth) * Math.min(delta * 30, 1);
    if (Math.abs(previousDepth - press.depth) > 0.000001) buttonGeometryChanged = true;
  });
  if (buttonGeometryChanged) updateButtonBankGeometry();

  knobAngle += (knobTargetAngle - knobAngle) * Math.min(delta * 13, 1);
  if (knobMesh) knobMesh.rotation.x = knobAngle;

  if (toaster) {
    const readyDrift = game.state === 'ready' && !reducedMotion.matches ? 0.00035 : 0;
    const dangerRattle = game.state === 'toasting' && !reducedMotion.matches ? visualDanger : 0;
    toaster.rotation.z = Math.sin(now * (0.0005 + dangerRattle * 0.025)) * (readyDrift * 2 + dangerRattle * 0.006);
    toaster.position.x = Math.sin(now * 0.047) * dangerRattle * 0.0012;
    toaster.position.y = Math.sin(now * (0.001 + dangerRattle * 0.038)) * (readyDrift + dangerRattle * 0.0009);
    if (game.state === 'ready' && now - lastControlProjection > 32) {
      lastControlProjection = now;
      updateControlScreenPositions();
    }
  }

  renderer.render(scene, camera);
}

resize();
requestAnimationFrame(render);
