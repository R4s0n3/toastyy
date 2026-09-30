// Clearances measured in toaster.glb's local coordinates, including its inner guides.
export const toastLayout = {
  slotCenters: [-0.0215, 0.0215],
  baseY: 0.177,
  travel: 0.035,
  thickness: 0.014,
};

const gravity = 0.85;

export function sampleToastPop(startY, velocity, age) {
  // Land on the raised carriage, starting from the actual lowered position.
  const landingTime = (velocity + Math.sqrt(velocity * velocity + 2 * gravity * startY)) / gravity;
  const landed = age >= landingTime;
  return {
    offset: landed ? 0 : startY + velocity * age - gravity * age * age / 2,
    landed,
  };
}
