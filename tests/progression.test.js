import test from 'node:test';
import assert from 'node:assert/strict';
import { toastSkins, restoreProgression, levelProgress, awardExperience, equipSkin } from '../src/progression.js';

const fresh = () => restoreProgression(null, null);

test('starts with dry toast and saves cumulative experience between sessions', () => {
  let progression = fresh();
  assert.equal(progression.equipped, 'dry');
  assert.equal(levelProgress(progression).current.level, 1);
  progression = awardExperience(progression, 'nice').progression;
  progression = restoreProgression(JSON.parse(JSON.stringify(progression)), null);
  assert.equal(progression.xp, 45);
  assert.equal(levelProgress(progression).next.id, 'prism');
  const reward = awardExperience(progression, 'pale');
  assert.deepEqual(reward.unlocked, []);
  assert.equal(reward.progression.equipped, 'dry');
  assert.equal(reward.progression.saves, 2);
});

test('levels unlock at exact thresholds and never disappear after a miss', () => {
  for (const skin of toastSkins.slice(1)) {
    const before = restoreProgression({version: 2, xp: skin.xp - 5, equipped: 'dry', saves: 4}, null);
    assert.notEqual(levelProgress(before).current.id, skin.id);
    const reward = awardExperience(before, 'miss');
    assert.equal(reward.progression.xp, skin.xp);
    assert.equal(reward.progression.saves, 4);
    assert.deepEqual(reward.unlocked.map(item => item.id), [skin.id]);
    assert.equal(reward.progression.equipped, skin.id);
    assert.deepEqual(awardExperience(reward.progression, 'miss').unlocked, []);
  }
});

test('locked skins cannot be equipped and unlocked earlier skins can be chosen', () => {
  const initial = fresh();
  assert.equal(equipSkin(initial, 'gold'), initial);
  assert.equal(equipSkin(initial, 'unknown'), initial);
  const leveled = awardExperience(initial, 'perfect').progression;
  assert.equal(equipSkin(leveled, 'dry').equipped, 'dry');
  assert.equal(restoreProgression({...leveled, equipped:'gold'}, null).equipped, 'dry');
});

test('perfect timing and streaks earn more XP; invalid events earn nothing', () => {
  const initial = fresh();
  assert.equal(awardExperience(initial, 'early').earned, 12);
  assert.equal(awardExperience(initial, 'perfect', 6).earned, 110);
  assert.equal(awardExperience(initial, 'perfect', 100).earned, 110);
  assert.equal(awardExperience(initial, 'missing').progression, initial);
  assert.equal(initial.xp, 0);
});

test('legacy play counts toward new levels and damaged saves recover', () => {
  assert.equal(restoreProgression(null, {saves:8}, {perfects:2,best:2000}).xp, 270);
  assert.equal(restoreProgression({version:2,xp:'bad',equipped:'prism',saves:-3},null).equipped,'dry');
  assert.equal(restoreProgression({version:2,xp:Infinity},null).xp,0);
  assert.equal(restoreProgression({version:2,xp:1000000,equipped:'prism'},null).equipped,'prism');
  assert.equal(levelProgress({xp:1000000}).next,undefined);
});


test('launch collection preserves old XP while replacing retired skins', () => {
  assert.deepEqual(toastSkins.map(skin => skin.id), ['dry', 'prism']);
  const migrated = restoreProgression({version:2,xp:3000,equipped:'gold',saves:20}, null);
  assert.equal(migrated.xp,3000);
  assert.equal(migrated.saves,20);
  assert.equal(migrated.equipped,'dry');
  assert.equal(equipSkin(migrated,'prism'),migrated);
  assert.equal(levelProgress(migrated).next.xp,1000000);
});
