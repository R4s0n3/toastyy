import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import * as THREE from 'three';
import { toastLayout, sampleToastPop } from '../src/toast-motion.js';

function toasterMeshes() {
  const bytes = readFileSync(new URL('../toaster.glb', import.meta.url));
  const jsonLength = bytes.readUInt32LE(12);
  const gltf = JSON.parse(bytes.subarray(20, 20 + jsonLength));
  const binary = bytes.subarray(28 + jsonLength);
  const attribute = (index) => {
    const accessor = gltf.accessors[index];
    const view = gltf.bufferViews[accessor.bufferView];
    const offset = (view.byteOffset || 0) + (accessor.byteOffset || 0);
    const Constructor = { 5126: Float32Array, 5125: Uint32Array, 5123: Uint16Array }[accessor.componentType];
    const size = accessor.type === 'VEC3' ? 3 : 1;
    const data = binary.subarray(offset, offset + accessor.count * size * Constructor.BYTES_PER_ELEMENT);
    return new THREE.BufferAttribute(new Constructor(data.buffer.slice(data.byteOffset, data.byteOffset + data.byteLength)), size);
  };
  return gltf.nodes.filter(node => node.mesh !== undefined).flatMap(node => gltf.meshes[node.mesh].primitives.map(primitive => {
    const geometry = new THREE.BufferGeometry();
    geometry.setAttribute('position', attribute(primitive.attributes.POSITION));
    geometry.setIndex(attribute(primitive.indices));
    const mesh = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ side: THREE.DoubleSide }));
    mesh.name = node.name;
    mesh.updateMatrixWorld();
    return mesh;
  }));
}

test('both bread footprints clear the actual toaster shell and inner guides throughout vertical travel', () => {
  const meshes = toasterMeshes();
  const ray = new THREE.Raycaster();
  ray.far = 0.165; // From above the popup apex to below the fully lowered bread.
  for (const center of toastLayout.slotCenters) {
    for (let xStep = 0; xStep <= 16; xStep += 1) {
      const x = -0.0415 + xStep / 16 * 0.083; // Full beveled crust width.
      for (let zStep = 0; zStep <= 8; zStep += 1) {
        const z = center - toastLayout.thickness / 2 + zStep / 8 * toastLayout.thickness;
        ray.set(new THREE.Vector3(x, 0.26, z), new THREE.Vector3(0, -1, 0));
        const hits = ray.intersectObjects(meshes, false);
        assert.equal(hits.length, 0, `Bread intersects ${hits[0]?.object.name} at x=${x}, z=${z}`);
      }
    }
  }
});

test('popping starts continuously from any carriage position and settles on the raised stop', () => {
  for (const start of [0, -toastLayout.travel / 2, -toastLayout.travel]) {
    for (const velocity of [0.32, 0.328, 0.35, 0.358, 0.38, 0.388]) {
      assert.equal(sampleToastPop(start, velocity, 0).offset, start);
      let previous = start;
      let apex = start;
      for (let frame = 1; frame <= 120; frame += 1) {
        const pop = sampleToastPop(start, velocity, frame / 120);
        assert(Number.isFinite(pop.offset));
        assert(pop.offset >= start - 1e-10, 'never falls below the lowered carriage');
        assert(Math.abs(pop.offset - previous) < 0.004, 'no teleport when launching or landing');
        apex = Math.max(apex, pop.offset);
        previous = pop.offset;
      }
      assert(apex > 0, 'clears the raised stop before falling back');
      assert.deepEqual(sampleToastPop(start, velocity, 2), { offset: 0, landed: true });
    }
  }
});
