import * as THREE from 'three';
import { GLTFLoader } from 'three/examples/jsm/loaders/GLTFLoader.js';
import { DecalGeometry } from 'three/examples/jsm/geometries/DecalGeometry.js';
import { RoomEnvironment } from 'three/examples/jsm/environments/RoomEnvironment.js';
import toasterUrl from '../toaster.glb?url';
import { applyToastSkin, skinThumbnail } from './toast-materials.js';
import { toastSkins, skinById, restoreProgression, awardExperience, levelProgress, equipSkin } from './progression.js';
import { toastLayout, sampleToastPop } from './toast-motion.js';
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
  knobHitbox: $('#knobHitbox'),
  frontSound: $('#frontSound'),
  frontHaptics: $('#frontHaptics'),
  frontSettings: $('#frontSettings'),
  frontRanks: $('#frontRanks'),
  buttonBankHitbox: $('#buttonBankHitbox'),
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
  resultFlavor: $('#resultFlavor'),
  resultTiming: $('#resultTiming'),
  spreadTray: $('#spreadTray'),
  collectionButton: $('#collectionButton'),
  collectionCount: $('#collectionCount'),
  collectionDialog: $('#collectionDialog'),
  collectionClose: $('#collectionClose'),
  collectionList: $('#collectionList'),
  collectionPreview: $('#collectionPreview'),
  collectionName: $('#collectionName'),
  collectionNote: $('#collectionNote'),
  collectionGoal: $('#collectionGoal'),
  collectionProgress: $('#collectionProgress'),
  collectionProgressText: $('#collectionProgressText'),
  collectionEquip: $('#collectionEquip'),
  collectionStatus: $('#collectionStatus'),
  resultUnlock: $('#resultUnlock'),
  equippedThumb: $('#equippedThumb'),
  equippedName: $('#equippedName'),
  playerLevel: $('#playerLevel'),
  levelMeter: $('#levelMeter'),
  nextLevel: $('#nextLevel'),
  collectionLevel: $('#collectionLevel'),
  collectionTotalXp: $('#collectionTotalXp'),
  collectionLevelMeter: $('#collectionLevelMeter'),
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
const formatScore = (value) => String(value).padStart(4, '0');
const supportedModes = ['soft', 'golden', 'crispy', 'chaos'];
const supportedSkins = toastSkins.map(skin => skin.id);

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
  skin: 'dry',
  roundSkin: 'dry',
  leverProgress: 0,
  roundStart: 0,
  popAt: 0,
  dangerAt: 0,
  resetAt: 0,
  round: 0,
  dragging: false,
  dragPointerId: null,
  dragStartY: 0,
  dragStartProgress: 0,
  leverAtLatch: false,
  knobDragging: false,
  knobStartX: 0,
  knobStartIndex: 0,
  knobMoved: false,
  pendingRunReset: false,
  hiddenAt: 0,
  nextTickAt: 0,
  dangerBuzzed: false,
};

let savedProgression;
let legacyPantry;
try { savedProgression = JSON.parse(readSetting('toastyy-progression', 'null')); } catch { /* Recover from an interrupted save. */ }
try { legacyPantry = JSON.parse(readSetting('toastyy-pantry', 'null')); } catch { /* Existing records still count. */ }
let progression = restoreProgression(savedProgression, legacyPantry, game);
game.skin = progression.equipped;
writeSetting('toastyy-progression', JSON.stringify(progression));
let collectionSelection = game.skin;
let newSkinIds = [];
let previewRenderer;
let previewScene;
let previewCamera;
let previewSlice;
let previewDragging = false;

const modes = {
  soft: { label: 'SOFT', min: 3700, range: 1500, multiplier: 0.8 },
  golden: { label: 'GOLDEN', min: 2800, range: 1450, multiplier: 1 },
  crispy: { label: 'CRISPY', min: 2100, range: 1150, multiplier: 1.25 },
  chaos: { label: 'CHAOS', min: 1450, range: 950, multiplier: 1.6 },
};
const modeOrder = Object.keys(modes);
const resultHeadlines = {
  early: 'Still doughy.',
  pale: 'A bit shy.',
  nice: 'Still edible.',
  golden: 'Breakfast is served.',
  perfect: 'Chef’s kiss.',
};

function ratingKey(rating) {
  if (rating === 'PERFECT!') return 'perfect';
  if (rating === 'GOLDEN!') return 'golden';
  if (rating === 'NICE SAVE') return 'nice';
  if (rating === 'A LITTLE PALE') return 'pale';
  if (rating === 'TOO EARLY') return 'early';
  return 'miss';
}

ui.best.textContent = formatScore(game.best);
ui.soundButton.setAttribute('aria-pressed', String(game.muted));
ui.soundButton.setAttribute('aria-label', game.muted ? 'Turn sound on' : 'Mute sound');
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
const leverParts = [];
let leverRail;
let frontCover;
let surfaceMarkings;
let framingPoints;
const leverTrack = { top: 0, bottom: 0, travel: 0, restOffset: 0, center: new THREE.Vector3() };
const dragRaycaster = new THREE.Raycaster();
const dragPlane = new THREE.Plane();
const dragPoint = new THREE.Vector3();
const dragNormal = new THREE.Vector3();
const dragPointer = new THREE.Vector2();
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
  sound: new THREE.Vector3(-0.1161, 0.1141, -0.0379),
  haptics: new THREE.Vector3(-0.1161, 0.0988, -0.0379),
  settings: new THREE.Vector3(-0.1161, 0.0835, -0.0379),
  ranks: new THREE.Vector3(-0.1161, 0.0682, -0.0379),
};
const projectedControls = {};
let toastGroup;
const toastBaseY = toastLayout.baseY;
let toastPop = 0;
let toastTarget = 0;
let toastMotionActive = false;
const crumbParticles = [];
const smokeParticles = [];
const steamParticles = [];
const sparkleParticles = [];
let steamEmit = 0;
let breadMap;
let grillMap;
let steamTexture;
let sparkleTexture;
let presentation = 0;
let presentationTarget = 0;
let visualHeat = 0;
let visualDanger = 0;
let latchKick = 0;
const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');

function toastShape(width, height, radius, crown = 0.0055) {
  const left = -width / 2;
  const right = width / 2;
  const shape = new THREE.Shape();
  shape.moveTo(left + radius, 0);
  shape.lineTo(right - radius, 0);
  shape.quadraticCurveTo(right, 0, right, radius);
  shape.lineTo(right, height - radius);
  shape.quadraticCurveTo(right * 0.55, height + crown, 0.006, height + crown * 0.25);
  shape.quadraticCurveTo(-right * 0.38, height + crown * 1.18, left, height - radius);
  shape.lineTo(left, radius);
  shape.quadraticCurveTo(left, 0, left + radius, 0);
  return shape;
}

function makeCanvasTexture(size, paint) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = size;
  paint(canvas.getContext('2d'), size);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.needsUpdate = true;
  return texture;
}

function createBreadTexture() {
  return makeCanvasTexture(512, (context, size) => {
    const base = context.createRadialGradient(256, 260, 45, 256, 256, 330);
    base.addColorStop(0, '#f7dda6');
    base.addColorStop(0.7, '#edc480');
    base.addColorStop(1, '#bf7936');
    context.fillStyle = base;
    context.fillRect(0, 0, size, size);
    for (let i = 0; i < 6500; i += 1) {
      context.fillStyle = i % 3 ? 'rgba(163,98,37,.10)' : 'rgba(255,241,204,.38)';
      context.beginPath();
      context.ellipse(Math.random() * size, Math.random() * size, 0.5 + Math.random() * 2.5, 0.5 + Math.random() * 1.5, Math.random() * Math.PI, 0, Math.PI * 2);
      context.fill();
    }
    for (let i = 0; i < 230; i += 1) {
      const x = Math.random() * size, y = Math.random() * size, radius = 1.5 + Math.random() * 4;
      const pore = context.createRadialGradient(x, y, 0, x, y, radius);
      pore.addColorStop(0, 'rgba(125,75,33,.4)');
      pore.addColorStop(0.6, 'rgba(195,140,70,.24)');
      pore.addColorStop(1, 'rgba(255,243,204,.3)');
      context.fillStyle = pore;
      context.fillRect(x - radius, y - radius, radius * 2, radius * 2);
    }
  });
}

function createGrillTexture() {
  return makeCanvasTexture(256, (context, size) => {
    context.clearRect(0, 0, size, size);
    for (let index = 0; index < 5; index += 1) {
      const x = 22 + index * 48;
      const gradient = context.createLinearGradient(x, 0, x + 16, 0);
      gradient.addColorStop(0, 'rgba(92, 42, 12, 0)');
      gradient.addColorStop(0.5, 'rgba(92, 42, 12, 0.55)');
      gradient.addColorStop(1, 'rgba(92, 42, 12, 0)');
      context.fillStyle = gradient;
      context.fillRect(x, 16, 16, size - 32);
    }
  });
}

function createSteamTexture() {
  return makeCanvasTexture(64, (context) => {
    const gradient = context.createRadialGradient(32, 32, 2, 32, 32, 30);
    gradient.addColorStop(0, 'rgba(255,248,230,0.72)');
    gradient.addColorStop(0.4, 'rgba(255,214,150,0.28)');
    gradient.addColorStop(1, 'rgba(255,200,120,0)');
    context.fillStyle = gradient;
    context.fillRect(0, 0, 64, 64);
  });
}

function createSparkleTexture() {
  return makeCanvasTexture(64, (context) => {
    context.translate(32, 32);
    context.fillStyle = '#fff4c8';
    context.beginPath();
    context.moveTo(0, -28);
    context.quadraticCurveTo(3, -3, 28, 0);
    context.quadraticCurveTo(3, 3, 0, 28);
    context.quadraticCurveTo(-3, 3, -28, 0);
    context.quadraticCurveTo(-3, -3, 0, -28);
    context.fill();
  });
}

function brownBread(material, heat, burnt = 0) {
  if (material.userData.skin && material.userData.skin !== 'dry') {
    material.color.setScalar(1 - clamp(heat, 0, 1) * 0.07 - clamp(burnt, 0, 1) * 0.6);
    return;
  }
  const h = clamp(heat, 0, 1);
  const char = clamp(burnt, 0, 1);
  material.color.setRGB(
    1 - h * 0.15 - char * 0.5,
    0.98 - h * 0.3 - char * 0.45,
    0.92 - h * 0.42 - char * 0.35,
  );
}

let crustGeometry;
let crumbGeometry;
function createToastSlice(kind = game.skin) {
  breadMap ||= createBreadTexture();
  grillMap ||= createGrillTexture();
  if (!crustGeometry) {
    crustGeometry = new THREE.ExtrudeGeometry(toastShape(0.075, 0.079, 0.014), {
      depth: 0.008, bevelEnabled: true, bevelSegments: 3, steps: 1, bevelSize: 0.004, bevelThickness: 0.003,
    });
    crustGeometry.center();
    const crustBounds = crustGeometry.boundingBox;
    const crustPositions = crustGeometry.getAttribute('position'), crustUvs = crustGeometry.getAttribute('uv');
    for (let i = 0; i < crustPositions.count; i += 1) {
      crustUvs.setXY(i, (crustPositions.getX(i) - crustBounds.min.x) / (crustBounds.max.x - crustBounds.min.x),
        (crustPositions.getY(i) - crustBounds.min.y) / (crustBounds.max.y - crustBounds.min.y));
    }
    crumbGeometry = new THREE.ExtrudeGeometry(toastShape(0.063, 0.068, 0.011, 0.0045), {
      depth: 0.009, bevelEnabled: true, bevelSegments: 2, steps: 1, bevelSize: 0.0025, bevelThickness: 0.002,
    });
    crumbGeometry.center();
    const bounds = crumbGeometry.boundingBox;
    const positions = crumbGeometry.getAttribute('position'), uvs = crumbGeometry.getAttribute('uv');
    for (let i = 0; i < positions.count; i += 1) {
      uvs.setXY(i, (positions.getX(i) - bounds.min.x) / (bounds.max.x - bounds.min.x),
        (positions.getY(i) - bounds.min.y) / (bounds.max.y - bounds.min.y));
    }
  }
  const slice = new THREE.Group();
  const outer = new THREE.Mesh(crustGeometry, new THREE.MeshPhysicalMaterial({ color: 0xb97637, roughness: 0.86 }));
  const inner = new THREE.Mesh(crumbGeometry, new THREE.MeshPhysicalMaterial({
    color: 0xffffff, map: breadMap, bumpMap: breadMap, bumpScale: 0.0004, roughness: 0.92,
  }));
  inner.position.z = 0.0045;
  const back = new THREE.Mesh(crumbGeometry, inner.material);
  back.position.z = -0.0045;
  outer.castShadow = inner.castShadow = true;
  outer.receiveShadow = inner.receiveShadow = true;
  const grill = new THREE.Mesh(
    new THREE.PlaneGeometry(0.056, 0.06),
    new THREE.MeshBasicMaterial({ map: grillMap, transparent: true, opacity: 0, depthWrite: false }),
  );
  grill.position.set(0, 0.002, 0.012);
  slice.add(outer, inner, back, grill);
  slice.userData.breadMaterial = inner.material;
  slice.userData.grill = grill;
  slice.userData.crustMaterial = outer.material;
  applyToastSkin(slice, kind, breadMap);
  return slice;
}

function createToast() {
  toastGroup = new THREE.Group();
  toastLayout.slotCenters.forEach((z) => {
    const slice = createToastSlice();
    const bounds = new THREE.Box3().setFromObject(slice);
    slice.scale.z = toastLayout.thickness / (bounds.max.z - bounds.min.z);
    slice.position.set(0, 0, z);
    slice.userData.basePosition = slice.position.clone();
    slice.userData.baseRotation = slice.rotation.clone();
    toastGroup.add(slice);
  });
  toastGroup.position.set(0, toastBaseY, 0);
  // The bread stays registered to the slots through every toaster pose and rattle.
  toaster.add(toastGroup);
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

  steamTexture ||= createSteamTexture();
  const steamCount = reducedQuality ? 8 : 14;
  for (let index = 0; index < steamCount; index += 1) {
    const particle = new THREE.Sprite(new THREE.SpriteMaterial({ map: steamTexture, transparent: true, depthWrite: false, opacity: 0 }));
    particle.visible = false;
    stage.add(particle);
    steamParticles.push(particle);
  }

  sparkleTexture ||= createSparkleTexture();
  const sparkleCount = reducedQuality ? 6 : 12;
  for (let index = 0; index < sparkleCount; index += 1) {
    const particle = new THREE.Sprite(new THREE.SpriteMaterial({ map: sparkleTexture, transparent: true, depthWrite: false, opacity: 0, color: 0xffd36a }));
    particle.visible = false;
    stage.add(particle);
    sparkleParticles.push(particle);
  }
}

function launchToast(kind) {
  if (!toastGroup) return;
  const startY = toastPop;
  toastPop = toastTarget = 0;
  toastGroup.position.y = toastBaseY;
  toastMotionActive = !reducedMotion.matches;
  const strength = kind === 'miss' ? 0.38 : kind === 'perfect' ? 0.35 : 0.32;
  toastGroup.children.forEach((slice, index) => {
    slice.visible = true;
    slice.position.copy(slice.userData.basePosition);
    slice.position.y = toastMotionActive ? startY : 0;
    slice.rotation.copy(slice.userData.baseRotation);
    slice.userData.launchStartY = startY;
    slice.userData.velocityY = strength + index * 0.008;
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
    slice.userData.launchAge = 0;
    slice.userData.toastHeat = 0;
    slice.userData.burnt = 0;
    applyToastSkin(slice, game.skin, breadMap);
    brownBread(slice.userData.breadMaterial, 0);
    slice.userData.breadMaterial.emissive.set(0x000000);
    slice.userData.breadMaterial.emissiveIntensity = 0;
    if (slice.userData.grill) slice.userData.grill.material.opacity = 0;
  });
}

function setToastSkin(_stage, kind = game.skin) {
  toastGroup?.children.forEach(slice => applyToastSkin(slice, kind, breadMap));
}

function crumbColor(kind, index) {
  if (kind === 'miss' && index % 3 === 0) return 0x4d3528;
  if (game.roundSkin !== 'dry' && index % 3 === 0) return skinById(game.roundSkin).color;
  if (kind === 'perfect') return index % 2 ? 0xffd36a : 0xe5a248;
  return index % 2 ? 0xe5a248 : 0xb96b2d;
}

function spawnCrumbs(kind) {
  const count = kind === 'perfect' ? 24 : kind === 'miss' ? 18 : 12;
  crumbParticles.slice(0, count).forEach((particle, index) => {
    particle.visible = true;
    particle.position.set(-0.02 + Math.random() * 0.05, 0.17 + Math.random() * 0.035, (Math.random() - 0.5) * 0.09);
    particle.scale.setScalar(0.55 + Math.random() * 1.1);
    particle.material.color.set(crumbColor(kind, index));
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

function spawnSteamPuff(heat, danger) {
  const particle = steamParticles.find((item) => !item.visible);
  if (!particle) return;
  particle.visible = true;
  particle.position.set(-0.02 + Math.random() * 0.05, 0.16 + Math.random() * 0.02, (Math.random() - 0.5) * 0.07);
  particle.scale.setScalar(0.012 + Math.random() * 0.01 + heat * 0.008);
  particle.material.opacity = 0.16 + heat * 0.24;
  particle.material.color.setRGB(1, 0.93 - danger * 0.16, 0.84 - danger * 0.28);
  particle.userData.velocity = new THREE.Vector3(
    (Math.random() - 0.5) * 0.012,
    0.028 + Math.random() * 0.03 + heat * 0.02,
    (Math.random() - 0.5) * 0.012,
  );
  particle.userData.life = 0.7 + Math.random() * 0.5;
}

function spawnSparkles() {
  sparkleParticles.forEach((particle) => {
    particle.visible = true;
    particle.position.set(-0.02 + Math.random() * 0.05, 0.19 + Math.random() * 0.05, (Math.random() - 0.5) * 0.08);
    particle.scale.setScalar(0.008 + Math.random() * 0.01);
    particle.material.opacity = 0;
    particle.userData.life = 0.45 + Math.random() * 0.45;
    particle.userData.phase = Math.random() * Math.PI * 2;
    particle.userData.velocity = new THREE.Vector3((Math.random() - 0.5) * 0.02, 0.02 + Math.random() * 0.03, (Math.random() - 0.5) * 0.02);
  });
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
  steamParticles.forEach((particle) => {
    if (!particle.visible) return;
    particle.userData.life -= delta;
    particle.position.addScaledVector(particle.userData.velocity, delta);
    particle.scale.multiplyScalar(1 + delta * 0.55);
    particle.material.opacity = clamp(particle.userData.life * 0.32, 0, 0.4);
    if (particle.userData.life <= 0) particle.visible = false;
  });
  sparkleParticles.forEach((particle) => {
    if (!particle.visible) return;
    particle.userData.life -= delta;
    particle.position.addScaledVector(particle.userData.velocity, delta);
    particle.userData.phase += delta * 10;
    particle.material.opacity = clamp(Math.sin(particle.userData.phase) * 0.7 + particle.userData.life, 0, 1);
    particle.scale.setScalar(0.007 + Math.abs(Math.sin(particle.userData.phase)) * 0.01);
    if (particle.userData.life <= 0) particle.visible = false;
  });
}

function updateToastMotion(delta) {
  if (!toastMotionActive || !toastGroup) return;
  let moving = false;
  toastGroup.children.forEach((slice) => {
    slice.userData.launchAge += delta;
    const pop = sampleToastPop(slice.userData.launchStartY, slice.userData.velocityY, slice.userData.launchAge);
    slice.position.y = slice.userData.basePosition.y + pop.offset;
    if (!pop.landed) moving = true;
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
    new THREE.BoxGeometry(0.0015, 0.006, 0.0018),
    new THREE.MeshBasicMaterial({ color: 0xffe3a1 }),
  );
  marker.position.set(-0.0133, 0.009, 0);
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
    if (child.name === 'front_cover_mesh') frontCover = child;
    if (child.name === 'front_cover_scroll_mesh') leverRail = child;
    if (child.name === 'scroll_button_mesh') {
      child.userData.restPosition = child.position.clone();
      leverParts.push(child);
    }
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
  prepareLever();
  createSurfaceMarkings();
  toaster.rotation.y = -THREE.MathUtils.degToRad(7);
  stage.add(toaster);
  createToast();
  setLever(0);
  stage.updateWorldMatrix(true, true);
  const framingBounds = new THREE.Box3().setFromObject(toaster).expandByObject(toastGroup);
  framingPoints = [];
  for (const x of [framingBounds.min.x, framingBounds.max.x]) {
    for (const y of [framingBounds.min.y, framingBounds.max.y]) {
      for (const z of [framingBounds.min.z, framingBounds.max.z]) framingPoints.push(new THREE.Vector3(x, y, z));
    }
  }
  resize();
  syncControlMaterials();
  setDifficulty(game.mode, false);
  game.state = 'ready';
  ui.status.querySelector('span').textContent = 'READY';
  ui.leverHitbox.classList.add('is-ready');
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

// The handle and its inset share a carriage; both stops come from the actual slot.
function prepareLever() {
  leverRail.geometry.computeBoundingBox();
  const handle = leverParts[0];
  handle.geometry.computeBoundingBox();
  const railBounds = leverRail.geometry.boundingBox;
  const handleBounds = handle.geometry.boundingBox;
  handleBounds.getCenter(leverTrack.center);
  const halfHeight = (handleBounds.max.y - handleBounds.min.y) / 2;
  const endClearance = 0.002;
  leverTrack.top = railBounds.max.y - halfHeight - endClearance;
  leverTrack.bottom = railBounds.min.y + halfHeight + endClearance;
  leverTrack.travel = leverTrack.top - leverTrack.bottom;
  leverTrack.restOffset = leverTrack.top - leverTrack.center.y;
  leverTrack.center.x = handleBounds.min.x;
}

function leverOffset() {
  return leverTrack.restOffset - leverTrack.travel * game.leverProgress;
}

function setLever(progress) {
  game.leverProgress = clamp(progress, 0, 1);
  leverParts.forEach((part) => {
    part.position.copy(part.userData.restPosition);
    part.position.y += leverOffset();
  });
  if (game.state === 'ready') toastTarget = -toastLayout.travel * game.leverProgress;
  updateButtonBankGeometry();
  updateLeverScreenPosition();
}

// Project the ink onto the housing, so it follows its curves, shadows and perspective.
function createSurfaceMarkings() {
  const canvas = document.createElement('canvas');
  canvas.width = 1024;
  canvas.height = 1408;
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  texture.anisotropy = Math.min(8, renderer.capabilities.getMaxAnisotropy());
  frontCover.updateWorldMatrix(true, false);
  const geometry = new DecalGeometry(
    frontCover,
    new THREE.Vector3(-0.113, 0.09, 0),
    new THREE.Euler(0, -Math.PI / 2, 0),
    new THREE.Vector3(0.112, 0.154, 0.018),
  );
  const material = new THREE.MeshStandardMaterial({
    map: texture, transparent: true, roughness: 0.92, metalness: 0,
    depthWrite: false, polygonOffset: true, polygonOffsetFactor: -4,
  });
  const markings = new THREE.Mesh(geometry, material);
  markings.name = 'housing_print';
  markings.receiveShadow = true;
  toaster.add(markings);
  surfaceMarkings = { canvas, texture };
  paintSurfaceMarkings();
  document.fonts.ready.then(() => { paintSurfaceMarkings(); resize(); });
}

function paintSurfaceMarkings() {
  if (!surfaceMarkings) return;
  const { canvas, texture } = surfaceMarkings;
  const context = canvas.getContext('2d');
  context.clearRect(0, 0, canvas.width, canvas.height);
  const scale = canvas.width / 0.112;
  const x = (z) => (z + 0.056) * scale;
  const y = (height) => (0.167 - height) * scale;
  const ink = '#474337';
  const accent = '#9e5e2e';
  const print = (label, z, height, size = 0.003, color = ink, spacing = 0.00035) => {
    context.font = `500 ${size * scale}px "DM Mono", monospace`;
    context.fillStyle = color;
    context.textBaseline = 'middle';
    const widths = [...label].map((letter) => context.measureText(letter).width);
    let cursor = x(z) - (widths.reduce((sum, width) => sum + width, 0) + (label.length - 1) * spacing * scale) / 2;
    [...label].forEach((letter, index) => {
      context.fillText(letter, cursor, y(height));
      cursor += widths[index] + spacing * scale;
    });
  };
  const line = (points, color = ink, width = 0.00035) => {
    context.strokeStyle = color;
    context.lineWidth = width * scale;
    context.lineCap = 'round';
    context.lineJoin = 'round';
    context.beginPath();
    points.forEach(([z, height], index) => context[index ? 'lineTo' : 'moveTo'](x(z), y(height)));
    context.stroke();
  };
  print('TOASTYY', 0, 0.151, 0.0043, ink, 0.0011);
  Object.entries(controlPoints).forEach(([kind, point]) => {
    print({ sound: 'SOUND', haptics: 'HAPTIC', settings: 'SETTINGS', ranks: 'RECORDS' }[kind], point.z, point.y + 0.0067, 0.0036, ink, 0.0002);
    if (kind === 'sound' || kind === 'haptics') {
      const active = kind === 'sound' ? !game.muted : game.haptics;
      context.beginPath();
      context.arc(x(point.z + 0.013), y(point.y), 0.00095 * scale, 0, Math.PI * 2);
      context.fillStyle = active ? accent : '#aaa497';
      context.fill();
    }
  });
  print('PULL', 0.022, 0.125, 0.0036);
  line([[0.021, 0.117], [0.021, 0.099]], accent);
  line([[0.0185, 0.102], [0.021, 0.099], [0.0235, 0.102]], accent);
  print('BROWNING', 0.034, 0.047, 0.0028, ink, 0.0002);
  print(modes[game.mode].label, 0.034, 0.0405, 0.0039, accent, 0.00025);
  [-0.86, -0.29, 0.29, 0.86].forEach((angle, index) => {
    const centerY = knobMesh.position.y;
    const selected = index === modeOrder.indexOf(game.mode);
    const radius = 0.019;
    line([
      [Math.sin(angle) * radius, centerY + Math.cos(angle) * radius],
      [Math.sin(angle) * (radius + 0.0023), centerY + Math.cos(angle) * (radius + 0.0023)],
    ], selected ? accent : '#8c8578', selected ? 0.0007 : 0.00035);
  });
  texture.needsUpdate = true;
}

function updateButtonBankGeometry() {
  if (buttonBankMesh && buttonBankBasePositions) {
    const positions = buttonBankMesh.geometry.getAttribute('position');
    leverInsertVertexIndices.forEach((index) => {
      positions.setY(index, buttonBankBasePositions[index * 3 + 1] + leverOffset());
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
  const point = leverTrack.center.clone();
  point.y = leverTrack.top - leverTrack.travel * game.leverProgress;
  const projected = projectToScreen(toaster.localToWorld(point));
  ui.leverHitbox.style.left = `${projected.x}px`;
  ui.leverHitbox.style.top = `${projected.y}px`;
  const edge = leverTrack.center.clone();
  edge.z += 0.012;
  // Use the visible carriage size, with a small touch allowance around the handle.
  edge.y = leverTrack.top - leverTrack.travel * game.leverProgress;
  const projectedEdge = projectToScreen(toaster.localToWorld(edge));
  ui.leverHitbox.style.width = `${Math.max(44, Math.abs(projectedEdge.x - projected.x) * 2 + 16)}px`;
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

  const knobPoint = new THREE.Vector3(knobMesh.geometry.boundingBox.min.x, 0, 0);
  knobMesh.localToWorld(knobPoint);
  const knobPosition = projectToScreen(knobPoint.clone());
  ui.knobHitbox.style.left = `${knobPosition.x}px`;
  ui.knobHitbox.style.top = `${knobPosition.y}px`;
  const rowHeight = (bottom - top) / 3;
  Object.values(elements).forEach((element) => {
    element.style.height = `${Math.min(44, rowHeight * 0.96)}px`;
  });
  const knobEdge = new THREE.Vector3(knobMesh.geometry.boundingBox.min.x, 0, 0.017);
  const knobRadius = Math.abs(projectToScreen(knobMesh.localToWorld(knobEdge)).x - knobPosition.x);
  const knobSize = Math.max(44, knobRadius * 2 + 10);
  ui.knobHitbox.style.width = `${knobSize}px`;
  ui.knobHitbox.style.height = `${knobSize}px`;
}

function syncControlMaterials() {
  paintSurfaceMarkings();
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
  paintSurfaceMarkings();
  ui.modeChip.textContent = `${modes[mode].label} · ${modes[mode].multiplier.toFixed(1)}×`;
  ui.knobHitbox.setAttribute('aria-label', `Turn difficulty knob. Current difficulty: ${modes[mode].label}`);
  ui.knobHitbox.setAttribute('aria-valuenow', String(index + 1));
  ui.knobHitbox.setAttribute('aria-valuetext', modes[mode].label);
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
  game.roundSkin = game.skin;
  ui.resultUnlock.hidden = true;
  setToastSkin('hidden');
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
  toastTarget = -toastLayout.travel;
  ui.leverHitbox.disabled = true;
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
  applyRoundReward(ratingKey(rating));
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
  const resultKind = ratingKey(rating);
  setToastSkin(resultKind, game.roundSkin);
  ui.resultCard.className = `result-card is-visible ${rating === 'PERFECT!' ? 'is-perfect' : ''} ${game.best > previousBest ? 'is-new-best' : ''}`.trim();
  ui.resultCard.setAttribute('aria-hidden', 'false');
  if (rating === 'PERFECT!') {
    toastGroup?.children.forEach((slice) => {
      slice.userData.breadMaterial.emissive.set(0xff7b20);
      slice.userData.breadMaterial.emissiveIntensity = 0.28;
    });
  }
  launchToast(resultKind);
  if (resultKind === 'perfect' && !reducedMotion.matches) spawnSparkles();
  spawnCrumbs(resultKind);
  if (rating === 'PERFECT!') {
    ui.game.classList.remove('is-perfect-flash');
    void ui.game.offsetWidth;
    ui.game.classList.add('is-perfect-flash');
  }
  animateLeverBack(70);
  setStatus('SAVED');
  setCopy('ROUND COMPLETE', resultHeadlines[resultKind], 'Your next slice is almost ready.');
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
  applyRoundReward('miss');
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
  ui.resultUnlock.hidden = true;
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
  ui.toasterMenu.classList.remove('is-hidden');
  ui.toasterMenu.inert = false;
  ui.toasterMenu.setAttribute('aria-hidden', 'false');
  ui.helpButton.disabled = false;
  leverReturnStart = 0;
  setLever(0);
  toastTarget = 0;
  resetToast();
  steamEmit = 0;
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
  setCopy(game.round ? 'SET UP THE NEXT SLICE' : 'YOUR TOASTER, YOUR RULES', 'Set it. Pull it.', 'Pull, time it right, and level up your toast.');
}

function pointerOnLeverPlane(event) {
  const rect = ui.canvas.getBoundingClientRect();
  dragPointer.set((event.clientX - rect.left) / rect.width * 2 - 1, 1 - (event.clientY - rect.top) / rect.height * 2);
  toaster.updateWorldMatrix(true, false);
  dragNormal.set(-1, 0, 0).transformDirection(toaster.matrixWorld);
  dragPlane.setFromNormalAndCoplanarPoint(dragNormal, toaster.localToWorld(leverTrack.center.clone()));
  dragRaycaster.setFromCamera(dragPointer, camera);
  if (!dragRaycaster.ray.intersectPlane(dragPlane, dragPoint)) return null;
  return toaster.worldToLocal(dragPoint).y;
}

function startDrag(event) {
  if (game.state !== 'ready' || game.dragging || !event.isPrimary || event.button !== 0) return;
  const localY = pointerOnLeverPlane(event);
  if (localY === null) return;
  event.preventDefault();
  leverReturnStart = 0;
  game.dragging = true;
  game.dragPointerId = event.pointerId;
  game.dragStartY = localY;
  game.dragStartProgress = game.leverProgress;
  game.leverAtLatch = false;
  ui.game.classList.add('is-dragging-lever');
  ui.leverHitbox.setPointerCapture(event.pointerId);
  playClick(72, 0.025);
}

function releaseLeverPointer() {
  const pointerId = game.dragPointerId;
  game.dragging = false;
  game.dragPointerId = null;
  ui.game.classList.remove('is-dragging-lever');
  if (pointerId !== null && ui.leverHitbox.hasPointerCapture(pointerId)) ui.leverHitbox.releasePointerCapture(pointerId);
}

function moveDrag(event) {
  if (!game.dragging || event.pointerId !== game.dragPointerId) return;
  const localY = pointerOnLeverPlane(event);
  if (localY === null) return;
  setLever(game.dragStartProgress + (game.dragStartY - localY) / leverTrack.travel);
  // A single detent near the catch, while the carriage stays attached to the pointer.
  if (game.leverProgress >= 0.9 && !game.leverAtLatch) {
    game.leverAtLatch = true;
    playClick(94, 0.022);
    buzz(8);
  } else if (game.leverProgress < 0.85) game.leverAtLatch = false;
  if (game.leverProgress >= 0.98) {
    releaseLeverPointer();
    setLever(1);
    startRound();
  }
}

function endDrag(event) {
  if (!game.dragging || event.pointerId !== game.dragPointerId) return;
  releaseLeverPointer();
  animateLeverBack();
}

function cancelLeverDrag() {
  if (!game.dragging) return;
  releaseLeverPointer();
  animateLeverBack();
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
ui.leverHitbox.addEventListener('lostpointercapture', endDrag);
window.addEventListener('blur', cancelLeverDrag);
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
  if (event.code !== 'Space' || ui.helpDialog.open || ui.ranksDialog.open || ui.collectionDialog.open) return;
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

function refreshCollectionControls() {
  const level = levelProgress(progression);
  const equipped = skinById(game.skin);
  ui.equippedThumb.src = skinThumbnail(equipped.id);
  ui.equippedName.textContent = equipped.name;
  ui.playerLevel.textContent = `LV. ${String(level.current.level).padStart(2, '0')}`;
  ui.collectionCount.textContent = `${level.current.level} / ${toastSkins.length}`;
  ui.levelMeter.max = level.next ? level.needed : 1;
  ui.levelMeter.value = level.next ? level.earned : 1;
  ui.nextLevel.textContent = level.next ? `${level.next.xp - level.xp} XP to ${level.next.name}` : 'Every toast, earned.';
  ui.collectionButton.classList.toggle('has-new', newSkinIds.length > 0);
  ui.collectionButton.setAttribute('aria-label', `Toast collection. Level ${level.current.level}. Equipped: ${equipped.name}. ${ui.nextLevel.textContent}`);
  ui.collectionLevel.textContent = `LEVEL ${String(level.current.level).padStart(2, '0')}`;
  ui.collectionTotalXp.textContent = `${level.xp.toLocaleString('en')} XP${level.next ? ` / ${level.next.xp.toLocaleString('en')} XP` : ' · COLLECTION COMPLETE'}`;
  ui.collectionLevelMeter.max = ui.levelMeter.max;
  ui.collectionLevelMeter.value = ui.levelMeter.value;
}

function applyRoundReward(rating) {
  const reward = awardExperience(progression, rating, game.streak);
  progression = reward.progression;
  game.skin = progression.equipped;
  newSkinIds = [...new Set([...newSkinIds, ...reward.unlocked.map(skin => skin.id)])];
  writeSetting('toastyy-progression', JSON.stringify(progression));
  ui.resultFlavor.textContent = `+${reward.earned} XP · ${rating === 'miss' ? 'keep going' : 'toast experience'}`;
  ui.resultUnlock.hidden = reward.unlocked.length === 0;
  if (reward.unlocked.length) {
    const latest = reward.unlocked.at(-1);
    ui.resultUnlock.dataset.skin = latest.id;
    ui.resultUnlock.textContent = `LEVEL ${latest.level} · ${latest.name} unlocked ↗`;
  }
  refreshCollectionControls();
}

function selectSkin(id) {
  if (!['ready', 'result'].includes(game.state) || !supportedSkins.includes(id)) return;
  const next = equipSkin(progression, id);
  if (next === progression) return;
  progression = next;
  game.skin = progression.equipped;
  writeSetting('toastyy-progression', JSON.stringify(progression));
  refreshCollectionControls();
  if (game.state === 'ready') setToastSkin('idle');
  playClick(220, 0.04);
  buzz(8);
}

function createCollectionPreview() {
  if (previewRenderer) return;
  previewRenderer = new THREE.WebGLRenderer({ canvas: ui.collectionPreview, antialias: true, alpha: true });
  previewRenderer.setPixelRatio(Math.min(window.devicePixelRatio, 2));
  previewRenderer.outputColorSpace = THREE.SRGBColorSpace;
  previewRenderer.toneMapping = THREE.ACESFilmicToneMapping;
  previewRenderer.toneMappingExposure = 0.92;
  previewRenderer.shadowMap.enabled = true;
  previewRenderer.shadowMap.type = THREE.PCFSoftShadowMap;
  previewScene = new THREE.Scene();
  const generator = new THREE.PMREMGenerator(previewRenderer);
  const room = new RoomEnvironment();
  previewScene.environment = generator.fromScene(room, 0.04).texture;
  room.dispose();
  generator.dispose();
  previewCamera = new THREE.OrthographicCamera(-0.057, 0.057, 0.057, -0.057, 0.01, 1);
  previewCamera.position.set(0.025, 0.018, 0.2);
  previewCamera.lookAt(0, 0, 0);
  previewScene.add(new THREE.HemisphereLight(0xfff7df, 0x857253, 1.6));
  const light = new THREE.DirectionalLight(0xfff5de, 2.1);
  light.position.set(-0.1, 0.12, 0.18);
  light.castShadow = true;
  light.shadow.mapSize.set(1024, 1024);
  Object.assign(light.shadow.camera, { left: -0.1, right: 0.1, top: 0.1, bottom: -0.1, near: 0.01, far: 1 });
  light.shadow.bias = -0.00015;
  previewScene.add(light);
  const fill = new THREE.DirectionalLight(0xffffff, 1.1);
  fill.position.set(0.1, -0.05, 0.12);
  previewScene.add(fill);
  previewSlice = createToastSlice();
  previewSlice.rotation.set(0.08, -0.18, -0.12);
  previewScene.add(previewSlice);
  const contact = new THREE.Mesh(new THREE.PlaneGeometry(0.4, 0.4), new THREE.ShadowMaterial({ opacity: 0.17 }));
  contact.position.z = -0.009;
  contact.receiveShadow = true;
  previewScene.add(contact);
}

function renderCollectionPreview() {
  if (!ui.collectionDialog.open) return;
  createCollectionPreview();
  const width = ui.collectionPreview.clientWidth, height = ui.collectionPreview.clientHeight;
  if (!width || !height) return;
  previewRenderer.setSize(width, height, false);
  const aspect = width / height;
  const halfHeight = 0.057 / Math.min(aspect, 1);
  previewCamera.left = -halfHeight * aspect;
  previewCamera.right = halfHeight * aspect;
  previewCamera.top = halfHeight;
  previewCamera.bottom = -halfHeight;
  previewCamera.updateProjectionMatrix();
  applyToastSkin(previewSlice, collectionSelection, breadMap);
  previewRenderer.render(previewScene, previewCamera);
}

function showCollectionSkin(id) {
  collectionSelection = id;
  const skin = skinById(id);
  const unlocked = skin.xp <= progression.xp;
  const equipped = game.skin === id;
  ui.collectionName.textContent = skin.name;
  ui.collectionNote.textContent = skin.note;
  ui.collectionGoal.textContent = unlocked ? (id === 'dry' ? 'Your first slice. Everybody starts here.' : `Level ${skin.level} reached. Yours to keep.`) : `Reach level ${skin.level} · ${skin.xp.toLocaleString('en')} total XP`;
  ui.collectionProgress.max = Math.max(1, skin.xp);
  ui.collectionProgress.value = unlocked ? Math.max(1, skin.xp) : progression.xp;
  ui.collectionProgressText.textContent = unlocked ? 'UNLOCKED' : `${skin.xp - progression.xp} XP TO GO`;
  ui.collectionStatus.textContent = `LV. ${String(skin.level).padStart(2, '0')} / ${skin.finish}`;
  ui.collectionEquip.disabled = !unlocked || equipped;
  ui.collectionEquip.textContent = equipped ? 'YOUR CURRENT TOAST' : unlocked ? 'MAKE THIS MY TOAST' : `UNLOCKS AT LEVEL ${skin.level}`;
  ui.collectionDialog.style.setProperty('--skin-color', skin.color);
  ui.collectionPreview.setAttribute('aria-label', `Preview of ${skin.name} toast. Move across the preview to see its material in the light.`);
  [...ui.collectionList.children].forEach(button => button.setAttribute('aria-pressed', String(button.dataset.skin === id)));
  if (previewSlice) previewSlice.rotation.set(0.08, -0.18, -0.12);
  renderCollectionPreview();
}

function openCollection(id = game.skin) {
  if (!['ready', 'result'].includes(game.state)) return;
  ui.collectionList.replaceChildren();
  toastSkins.forEach(skin => {
    const button = document.createElement('button');
    button.type = 'button';
    button.dataset.skin = skin.id;
    button.style.setProperty('--swatch', skin.color);
    const thumb = document.createElement('img');
    thumb.src = skinThumbnail(skin.id);
    thumb.alt = '';
    const level = document.createElement('span');
    level.className = 'skin-level';
    level.textContent = `LV. ${String(skin.level).padStart(2, '0')}`;
    const name = document.createElement('strong');
    name.textContent = skin.name;
    const detail = document.createElement('small');
    const unlocked = skin.xp <= progression.xp;
    detail.textContent = game.skin === skin.id ? 'EQUIPPED' : unlocked ? skin.finish : `${skin.xp.toLocaleString('en')} XP`;
    button.classList.toggle('is-locked', !unlocked);
    button.setAttribute('aria-label', `${skin.name}, level ${skin.level}. ${unlocked ? 'Unlocked' : `${skin.xp} XP required`}`);
    button.append(level, thumb, name, detail);
    button.addEventListener('click', () => showCollectionSkin(skin.id));
    ui.collectionList.append(button);
  });
  newSkinIds = [];
  refreshCollectionControls();
  if (!ui.collectionDialog.open) ui.collectionDialog.showModal();
  showCollectionSkin(id);
}

ui.collectionButton.addEventListener('click', () => openCollection());
ui.collectionClose.addEventListener('click', () => ui.collectionDialog.close());
ui.resultUnlock.addEventListener('click', () => openCollection(ui.resultUnlock.dataset.skin || game.skin));
ui.collectionEquip.addEventListener('click', () => {
  selectSkin(collectionSelection);
  ui.collectionDialog.close();
});
ui.collectionPreview.addEventListener('pointerdown', (event) => {
  if (!event.isPrimary || event.button !== 0) return;
  previewDragging = true;
  ui.collectionPreview.setPointerCapture(event.pointerId);
});
ui.collectionPreview.addEventListener('pointermove', (event) => {
  if (!previewSlice || reducedMotion.matches || (event.pointerType !== 'mouse' && !previewDragging)) return;
  const rect = ui.collectionPreview.getBoundingClientRect();
  previewSlice.rotation.y = clamp((event.clientX - rect.left) / rect.width - 0.5, -0.5, 0.5) * 1.3;
  previewSlice.rotation.x = clamp((event.clientY - rect.top) / rect.height - 0.5, -0.5, 0.5) * 0.45;
  renderCollectionPreview();
});
function releasePreview(event) {
  previewDragging = false;
  if (ui.collectionPreview.hasPointerCapture(event.pointerId)) ui.collectionPreview.releasePointerCapture(event.pointerId);
}
ui.collectionPreview.addEventListener('pointerup', releasePreview);
ui.collectionPreview.addEventListener('pointercancel', releasePreview);
ui.collectionPreview.addEventListener('lostpointercapture', () => { previewDragging = false; });
new ResizeObserver(renderCollectionPreview).observe(ui.collectionPreview);
refreshCollectionControls();

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
  cancelLeverDrag();
  const rect = ui.game.getBoundingClientRect();
  if (!rect.width || !rect.height) return;
  renderer.setSize(rect.width, rect.height, false);
  camera.aspect = rect.width / rect.height;
  camera.clearViewOffset();
  camera.fov = 28;
  camera.position.set(-0.74, 0.26, 0);
  camera.lookAt(0, 0.085, 0);
  camera.updateProjectionMatrix();
  camera.updateMatrixWorld();
  if (framingPoints) {
    const contentTop = ui.gameCopy.getBoundingClientRect().bottom - rect.top + 18;
    const contentBottom = rect.height - ui.spreadTray.offsetHeight - 45;
    const availableHeight = Math.max(100, contentBottom - contentTop);
    const screenBounds = () => {
      const points = framingPoints.map((point) => projectToScreen(point.clone()));
      return {
        left: Math.min(...points.map((point) => point.x)), right: Math.max(...points.map((point) => point.x)),
        top: Math.min(...points.map((point) => point.y)), bottom: Math.max(...points.map((point) => point.y)),
      };
    };
    let bounds = screenBounds();
    const fit = Math.min(rect.width * 0.88 / (bounds.right - bounds.left), availableHeight / (bounds.bottom - bounds.top));
    camera.fov = THREE.MathUtils.radToDeg(2 * Math.atan(Math.tan(THREE.MathUtils.degToRad(camera.fov / 2)) / fit));
    camera.updateProjectionMatrix();
    bounds = screenBounds();
    camera.setViewOffset(rect.width, rect.height,
      (bounds.left + bounds.right - rect.width) / 2,
      (bounds.top + bounds.bottom - contentTop - contentBottom) / 2,
      rect.width, rect.height);
  }
  updateControlScreenPositions();
}

const resizeObserver = new ResizeObserver(resize);
resizeObserver.observe(ui.game);

document.addEventListener('visibilitychange', () => {
  const now = performance.now();
  if (document.hidden) {
    cancelLeverDrag();
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
  } else if (!game.dragging) {
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
    const elapsed = Math.max(0, now - leverReturnStart) / 1000;
    const spring = reducedMotion.matches ? 0 : (1 + 24 * elapsed) * Math.exp(-24 * elapsed);
    if (now >= leverReturnStart) setLever(spring < 0.001 ? 0 : leverReturnFrom * spring);
    if (spring < 0.001) leverReturnStart = 0;
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
    if (!reducedMotion.matches && heat > 0.25) {
      steamEmit += delta;
      if (steamEmit > THREE.MathUtils.lerp(0.3, 0.11, heat)) {
        spawnSteamPuff(heat, danger);
        steamEmit = 0;
      }
    }
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
        if (material) brownBread(material, heat);
      });
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
    if (!game.dragging) {
      toaster.rotation.z = Math.sin(now * (0.0005 + dangerRattle * 0.025)) * (readyDrift * 2 + dangerRattle * 0.006);
      toaster.position.x = Math.sin(now * 0.047) * dangerRattle * 0.0012;
      toaster.position.y = Math.sin(now * (0.001 + dangerRattle * 0.038)) * (readyDrift + dangerRattle * 0.0009);
    }
    if (game.state === 'ready' && (game.dragging || now - lastControlProjection > 32)) {
      lastControlProjection = now;
      updateControlScreenPositions();
    }
  }

  renderer.render(scene, camera);
}

resize();
requestAnimationFrame(render);
