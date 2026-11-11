export const toastSkins = [
  { id: 'dry', name: 'Dry toast', level: 1, xp: 0, finish: 'THE ORIGINAL', note: 'Just a little bread with a big future.', color: '#b9874b', metalness: 0, roughness: 0.9 },
  { id: 'prism', name: 'DAYDREAM', level: 2, xp: 1000000, finish: 'IRIDESCENT', note: 'Pearl, lilac, mint. A different color at every turn.', color: '#9b82bb', metalness: 0.55, roughness: 0.2 },
];

const safeCount = value => Number.isFinite(Number(value)) ? Math.min(Number.MAX_SAFE_INTEGER, Math.max(0, Math.floor(Number(value)))) : 0;
export const skinById = id => toastSkins.find(skin => skin.id === id) || toastSkins[0];

export function levelProgress(progression) {
  const xp = safeCount(progression.xp);
  const current = [...toastSkins].reverse().find(skin => xp >= skin.xp);
  const next = toastSkins[current.level];
  return { current, next, xp, earned: xp - current.xp, needed: next ? next.xp - current.xp : 0 };
}

export function restoreProgression(saved, legacy, records = {}) {
  const valid = saved?.version === 2;
  const legacySaves = Math.max(safeCount(legacy?.saves), safeCount(records.bestStreak));
  const xp = valid ? safeCount(saved.xp) : Math.max(legacySaves * 25 + safeCount(records.perfects) * 35, Math.floor(safeCount(records.best) * 0.05));
  const current = levelProgress({ xp }).current;
  const equipped = valid && toastSkins.some(skin => skin.id === saved.equipped && skin.xp <= xp) ? saved.equipped : current.id;
  return { version: 2, xp, equipped, saves: valid ? safeCount(saved.saves) : legacySaves };
}

export function equipSkin(progression, id) {
  const skin = toastSkins.find(item => item.id === id);
  return skin && skin.xp <= progression.xp ? { ...progression, equipped: id } : progression;
}

export function awardExperience(progression, rating, streak = 0) {
  const amounts = { early: 12, pale: 25, nice: 45, golden: 70, perfect: 100, miss: 5 };
  const base = amounts[rating];
  if (base === undefined) return { progression, earned: 0, unlocked: [] };
  const earned = base + (rating === 'miss' ? 0 : Math.min(10, Math.max(0, safeCount(streak) - 1) * 2));
  const xp = safeCount(progression.xp + earned);
  const unlocked = toastSkins.filter(skin => skin.xp > progression.xp && skin.xp <= xp);
  return {
    progression: { ...progression, xp, saves: safeCount(progression.saves) + (rating === 'miss' ? 0 : 1), equipped: unlocked.at(-1)?.id || progression.equipped },
    earned, unlocked,
  };
}
