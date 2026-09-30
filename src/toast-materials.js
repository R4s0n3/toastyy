import * as THREE from 'three';
import { skinById } from './progression.js';

const maps = new Map();
const thumbnails = new Map();
function randomSource(seed) {
  return () => { seed = (seed * 1664525 + 1013904223) >>> 0; return seed / 4294967296; };
}

function paintSkin(id) {
  const canvas = document.createElement('canvas');
  canvas.width = canvas.height = 512;
  const c = canvas.getContext('2d');
  const random = randomSource([...id].reduce((n, char) => n + char.charCodeAt(0), 31));
  const palettes = {
    dry: ['#f6d698', '#e8b568'], doodle: ['#fff0c2', '#f3d486'], berry: ['#ffd4da', '#f298ba'],
    porcelain: ['#fffcf0', '#dfede9'], copper: ['#e5ac85', '#94553b'], chrome: ['#d3dee4', '#a0aebc'],
    gold: ['#ffe6a0', '#c19332'], prism: ['#c8e9dc', '#c8b2e3'],
  };
  const palette = palettes[id];
  const base = c.createLinearGradient(0, 0, 512, 512);
  base.addColorStop(0, palette[0]); base.addColorStop(1, palette[1]);
  c.fillStyle = base; c.fillRect(0, 0, 512, 512);
  c.lineCap = 'round'; c.lineJoin = 'round';
  if (id === 'doodle') {
    const colors = ['#da653b', '#397f71', '#dca022', '#71549c', '#c64d7c'];
    for (let i = 0; i < 16; i += 1) {
      c.save(); c.translate(50 + (i % 4) * 137, 48 + Math.floor(i / 4) * 135); c.rotate(random() * 0.7 - 0.35);
      c.strokeStyle = colors[i % colors.length]; c.fillStyle = c.strokeStyle; c.lineWidth = 6;
      if (i % 3 === 0) {
        c.beginPath(); c.arc(18, 16, 26, 0, Math.PI * 2); c.stroke();
        c.beginPath(); c.arc(18, 15, 13, 0.15, Math.PI - 0.15); c.stroke();
        c.beginPath(); c.arc(8, 6, 2.5, 0, Math.PI * 2); c.arc(27, 6, 2.5, 0, Math.PI * 2); c.fill();
      } else if (i % 3 === 1) {
        c.beginPath(); c.moveTo(-6, 7); c.bezierCurveTo(5, -22, 18, 39, 32, 8); c.bezierCurveTo(43, -18, 51, 32, 64, 8); c.stroke();
      } else {
        for (let petal = 0; petal < 7; petal += 1) {
          c.save(); c.rotate(petal / 7 * Math.PI * 2); c.beginPath(); c.ellipse(0, -19, 7, 15, 0, 0, Math.PI * 2); c.fill(); c.restore();
        }
        c.fillStyle = '#fff4ca'; c.beginPath(); c.arc(0, 0, 8, 0, Math.PI * 2); c.fill();
      }
      c.restore();
    }
    for (let i = 0; i < 60; i += 1) {
      c.fillStyle = colors[i % colors.length]; c.globalAlpha = 0.7;
      c.beginPath(); c.arc(random() * 512, random() * 512, 1 + random() * 3, 0, Math.PI * 2); c.fill();
    }
  } else if (id === 'berry') {
    const colors = ['#e25884', '#ad436e', '#fff0bb', '#f6a450'];
    for (let i = -2; i < 8; i += 1) {
      c.strokeStyle = colors[(i + 4) % 4]; c.lineWidth = 25 + (i % 2) * 8;
      c.beginPath(); c.moveTo(-70, i * 100);
      c.bezierCurveTo(210, i * 100 - 190, 70, i * 100 + 250, 580, i * 100 + 70); c.stroke();
    }
  } else if (id === 'porcelain') {
    c.strokeStyle = '#275899';
    for (let row = 0; row < 5; row += 1) {
      for (let col = 0; col < 5; col += 1) {
        c.save(); c.translate(col * 128, row * 126);
        c.lineWidth = 3.5 + random() * 1.5;
        for (let petal = 0; petal < 6; petal += 1) {
          c.save(); c.rotate(petal / 6 * Math.PI * 2); c.beginPath(); c.ellipse(0, -24, 8, 21, 0.2, 0, Math.PI * 2); c.stroke(); c.restore();
        }
        c.fillStyle = '#275899'; c.beginPath(); c.arc(0, 0, 5, 0, Math.PI * 2); c.fill();
        c.beginPath(); c.moveTo(39, 39); c.quadraticCurveTo(62, 15, 87, 40); c.quadraticCurveTo(68, 57, 39, 39); c.stroke();
        c.restore();
      }
    }
  } else if (id === 'copper' || id === 'chrome' || id === 'gold') {
    for (let i = 0; i < 1700; i += 1) {
      c.globalAlpha = random() * (id === 'chrome' ? 0.035 : 0.065);
      c.strokeStyle = i % 2 ? '#fff6e4' : '#43392e'; c.lineWidth = random() + 0.3;
      const y = random() * 512;
      c.beginPath(); c.moveTo(0, y); c.lineTo(512, y + random() * 1.5); c.stroke();
    }
    if (id === 'copper' || id === 'gold') {
      for (let i = 0; i < 210; i += 1) {
        c.globalAlpha = 0.035 + random() * 0.08; c.fillStyle = i % 2 ? '#fff1bc' : '#83532b';
        const x = random() * 512, y = random() * 512, size = 7 + random() * 23;
        c.fillRect(x, y, size, size * (0.5 + random()));
      }
    }
    if (id === 'gold') {
      c.globalAlpha = 0.25; c.strokeStyle = '#fff4c4'; c.lineWidth = 2;
      for (let i = 0; i < 18; i += 1) {
        const x = random() * 512, y = random() * 512;
        c.beginPath(); c.moveTo(x - 9, y); c.quadraticCurveTo(x, y, x, y - 13); c.quadraticCurveTo(x, y, x + 9, y); c.quadraticCurveTo(x, y, x, y + 13); c.quadraticCurveTo(x, y, x - 9, y); c.stroke();
      }
    }
  } else if (id === 'prism') {
    const image = c.createImageData(512, 512);
    for (let y = 0; y < 512; y += 1) {
      for (let x = 0; x < 512; x += 1) {
        const phase = x / 100 + Math.sin(y / 105) * 1.7 + y / 210;
        const i = (y * 512 + x) * 4;
        image.data[i] = 213 + 35 * Math.sin(phase);
        image.data[i + 1] = 212 + 33 * Math.sin(phase + 2.1);
        image.data[i + 2] = 224 + 27 * Math.sin(phase + 4.2);
        image.data[i + 3] = 255;
      }
    }
    c.putImageData(image, 0, 0);
    c.strokeStyle = '#fffdf6'; c.globalAlpha = 0.4; c.lineWidth = 2;
    for (let i = 0; i < 12; i += 1) {
      c.beginPath(); c.moveTo(-10, i * 75); c.bezierCurveTo(180, i * 75 - 100, 290, i * 75 + 120, 550, i * 75 + 20); c.stroke();
    }
  }
  // Fine pigment and pores keep the paint from looking like a flat UI graphic.
  for (let i = 0; i < 14000; i += 1) {
    c.globalAlpha = random() * (id === 'dry' ? 0.2 : 0.075);
    c.fillStyle = i % 2 ? '#fff8e4' : '#58402c';
    const size = id === 'dry' ? random() * 3 + 0.7 : random() * 1.5 + 0.5;
    c.fillRect(random() * 512, random() * 512, size, size);
  }
  c.globalAlpha = 1;
  return canvas;
}

function mapFor(id) {
  if (!maps.has(id)) {
    const texture = new THREE.CanvasTexture(paintSkin(id));
    texture.colorSpace = THREE.SRGBColorSpace;
    texture.anisotropy = 4;
    maps.set(id, texture);
  }
  return maps.get(id);
}

export function applyToastSkin(slice, id, breadMap) {
  if (slice.userData.skin === id) return;
  const skin = skinById(id);
  const dry = skin.id === 'dry';
  const face = slice.userData.breadMaterial;
  const crust = slice.userData.crustMaterial;
  for (const material of [face, crust]) {
    material.color.set(0xffffff);
    material.map = dry ? (material === face ? breadMap : null) : mapFor(skin.id);
    material.metalness = skin.metalness;
    material.roughness = skin.roughness;
    material.clearcoat = ['porcelain', 'prism'].includes(skin.id) ? 1 : 0;
    material.clearcoatRoughness = 0.12;
    material.iridescence = skin.id === 'prism' ? 1 : 0;
    material.iridescenceIOR = 1.35;
    material.iridescenceThicknessRange = [180, 420];
    material.bumpMap = dry ? breadMap : null;
    material.bumpScale = dry ? 0.0004 : 0;
    material.emissive.set(0x000000);
    material.emissiveIntensity = 0;
    material.userData.skin = skin.id;
    material.needsUpdate = true;
  }
  if (dry) crust.color.set(0xb97637);
  slice.userData.skin = skin.id;
}

export function skinThumbnail(id) {
  if (thumbnails.has(id)) return thumbnails.get(id);
  const skin = skinById(id);
  const canvas = document.createElement('canvas');
  canvas.width = 160; canvas.height = 176;
  const c = canvas.getContext('2d');
  c.translate(80, 88); c.rotate(-0.1); c.translate(-80, -88);
  const outline = new Path2D('M32 149Q19 150 20 136L20 51Q8 26 31 22Q56 3 80 20Q108 4 132 24Q151 32 140 52L140 137Q140 151 127 152Z');
  c.shadowColor = '#55442a25'; c.shadowBlur = 8; c.shadowOffsetY = 5;
  c.fillStyle = id === 'dry' ? '#b97637' : skin.color; c.fill(outline);
  c.shadowColor = 'transparent';
  c.save(); c.clip(outline);
  c.drawImage(mapFor(skin.id).image, 21, 22, 119, 129);
  if (skin.metalness > 0.5) {
    const sheen = c.createLinearGradient(20, 0, 138, 0);
    sheen.addColorStop(0, '#ffffff00'); sheen.addColorStop(0.3, '#fffefa90'); sheen.addColorStop(0.45, '#ffffff08'); sheen.addColorStop(0.8, '#58472838'); sheen.addColorStop(1, '#ffffff44');
    c.fillStyle = sheen; c.fillRect(0, 0, 160, 176);
  }
  c.strokeStyle = id === 'dry' ? '#b97637' : '#63544b35'; c.lineWidth = 7; c.stroke(outline);
  c.restore();
  const url = canvas.toDataURL('image/png');
  thumbnails.set(id, url);
  return url;
}
