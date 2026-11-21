#!/usr/bin/env node
/**
 * Validate the species roster against parts.json and biome coverage requirements.
 * Run from repo root: node scripts/validate_roster.js
 */

const fs = require('fs');
const path = require('path');

const REPO_ROOT = path.resolve(__dirname, '..');
const ROSTER_PATH = path.join(REPO_ROOT, 'web/stage/species/roster.json');
const PARTS_PATH = path.join(REPO_ROOT, 'web/studio/parts.json');

const REQUIRED_BIOMES = ['valley', 'forest', 'savanna', 'alpine', 'coast', 'caves', 'night', 'islets'];
const VALID_TEMPERAMENTS = [0, 1, 2];
const VALID_SIZE_CLASSES = ['tiny', 'small', 'medium', 'large', 'epic'];
const VALID_ACTIVITIES = ['day', 'night', 'day_night'];
const VALID_SOCIAL = ['solitary', 'pair', 'herd', 'pack', 'flock', 'colony'];

function loadJSON(filepath) {
  const content = fs.readFileSync(filepath, 'utf-8');
  return JSON.parse(content);
}

function main() {
  console.log('🔍 Validating species roster...\n');

  const roster = loadJSON(ROSTER_PATH);
  const parts = loadJSON(PARTS_PATH);

  // Build set of valid part IDs
  const validPartIds = new Set(parts.parts.map(p => p.id));
  console.log(`📦 Loaded ${validPartIds.size} valid part IDs from parts.json`);

  // Build set of known new parts (planned for P4-P8, not yet in parts.json)
  const knownNewParts = new Set([
    'espinas_dorsales', 'carapace_stone', 'jaw_crusher', 'rad_shield', 'insulation',
    'sac_cryo', 'sac_ink', 'senses_magnetic', 'skin_chroma', 'eye_zoom',
    'sac_electric', 'tail_heavy', 'echo_organ', 'sac_regenerative', 'mouth_vorous',
    'fuel_gland', 'plume_great', 'sac_explosive', 'trigger_jaw', 'leg_power',
    'foot_gecko', 'leg_sucker', 'leg_sprinter', 'sac_spitter', 'horn_crown',
    'shell_plate', 'tail_hammer', 'pua', 'cresta', 'fauces', 'aleta', 'tail_paddle',
    'frill_fan', 'eye_stalk', 'bulbo', 'oreja', 'placa', 'zanca', 'romo', 'tallo',
    'pezuna', 'pata', 'ojo', 'pico', 'mandible_shear', 'cuerno', 'asta',
    'antena', 'trompa', 'snout_trumpet', 'lure_lantern', 'arm_smasher', 'foot_spring',
    'foot_hoof', 'leg_power', 'wing_glider', 'beak_crusher', 'excavadora', 'arm_grasper',
    'sac_spitter', 'sac_cryo', 'sac_ink', 'senses_magnetic', 'skin_chroma', 'eye_zoom',
    'sac_electric', 'tail_heavy', 'echo_organ', 'sac_regenerative', 'mouth_vorous',
    'fuel_gland', 'plume_great', 'sac_explosive', 'trigger_jaw', 'leg_power',
    'foot_gecko', 'leg_sucker', 'leg_sprinter', 'rad_shield', 'insulation',
    'carapace_stone', 'jaw_crusher'
  ]);

  // Combined set of all acceptable part IDs
  const allValidPartIds = new Set([...validPartIds, ...knownNewParts]);

  let errors = [];
  let warnings = [];

  // 1. Check unique IDs
  const seenIds = new Set();
  const seenNames = new Set();
  for (const sp of roster.species) {
    if (seenIds.has(sp.id)) {
      errors.push(`Duplicate species id: ${sp.id}`);
    }
    seenIds.add(sp.id);

    if (seenNames.has(sp.name)) {
      errors.push(`Duplicate species name: ${sp.name}`);
    }
    seenNames.add(sp.name);
  }

  // 2. Validate each species
  const biomeCounts = {};
  for (const sp of roster.species) {
    // Required fields
    const requiredFields = ['id', 'name', 'biome', 'diet', 'temperament', 'size_class', 'activity', 'social', 'parts', 'drops', 'clue', 'behaviour', 'inspiration'];
    for (const field of requiredFields) {
      if (!sp.hasOwnProperty(field) || sp[field] === undefined || sp[field] === null || sp[field] === '') {
        errors.push(`${sp.id}: missing or empty required field "${field}"`);
      }
    }

    // Biome tracking
    biomeCounts[sp.biome] = (biomeCounts[sp.biome] || 0) + 1;

    // Temperament
    if (!VALID_TEMPERAMENTS.includes(sp.temperament)) {
      errors.push(`${sp.id}: invalid temperament ${sp.temperament} (must be 0, 1, or 2)`);
    }

    // Size class
    if (!VALID_SIZE_CLASSES.includes(sp.size_class)) {
      errors.push(`${sp.id}: invalid size_class "${sp.size_class}"`);
    }

    // Activity
    if (!VALID_ACTIVITIES.includes(sp.activity)) {
      errors.push(`${sp.id}: invalid activity "${sp.activity}"`);
    }

    // Social
    if (!VALID_SOCIAL.includes(sp.social)) {
      errors.push(`${sp.id}: invalid social "${sp.social}"`);
    }

    // Parts array
    if (!Array.isArray(sp.parts)) {
      errors.push(`${sp.id}: parts must be an array`);
    } else {
      for (const partId of sp.parts) {
        if (!allValidPartIds.has(partId)) {
          errors.push(`${sp.id}: part "${partId}" in parts[] not found in parts.json and not in known-new-parts list`);
        } else if (!validPartIds.has(partId)) {
          warnings.push(`${sp.id}: part "${partId}" in parts[] is a known-new-part (planned for future phase)`);
        }
      }
    }

    // Drops array (subset of parts)
    if (!Array.isArray(sp.drops)) {
      errors.push(`${sp.id}: drops must be an array`);
    } else {
      for (const partId of sp.drops) {
        if (!allValidPartIds.has(partId)) {
          errors.push(`${sp.id}: part "${partId}" in drops[] not found in parts.json and not in known-new-parts list`);
        } else if (!validPartIds.has(partId)) {
          warnings.push(`${sp.id}: part "${partId}" in drops[] is a known-new-part (planned for future phase)`);
        }
        if (!sp.parts.includes(partId)) {
          warnings.push(`${sp.id}: drop "${partId}" not listed in parts[] (should be a subset)`);
        }
      }
    }

    // Clue non-empty
    if (!sp.clue || sp.clue === 'none') {
      // 'none' is allowed for species without a recipe clue
    } else if (typeof sp.clue !== 'string') {
      errors.push(`${sp.id}: clue must be a string`);
    }
  }

  // 3. Biome coverage: each required biome must have >= 4 species
  for (const biome of REQUIRED_BIOMES) {
    const count = biomeCounts[biome] || 0;
    if (count === 0) {
      errors.push(`Biome "${biome}" has 0 species (need >= 4)`);
    } else if (count < 4) {
      errors.push(`Biome "${biome}" has only ${count} species (need >= 4)`);
    } else {
      console.log(`  ✅ Biome "${biome}": ${count} species`);
    }
  }

  // 4. Check for parts referenced that are not in parts.json nor known-new-parts
  for (const sp of roster.species) {
    for (const partId of [...sp.parts, ...sp.drops]) {
      if (!allValidPartIds.has(partId)) {
        warnings.push(`${sp.id}: part "${partId}" not in parts.json and not in known-new-parts list`);
      }
    }
  }

  // Summary
  console.log(`\n📊 Summary:`);
  console.log(`  Species total: ${roster.species.length}`);
  console.log(`  Biomes covered: ${Object.keys(biomeCounts).length}/${REQUIRED_BIOMES.length}`);
  console.log(`  Errors: ${errors.length}`);
  console.log(`  Warnings: ${warnings.length}`);

  if (warnings.length > 0) {
    console.log('\n⚠️  Warnings:');
    for (const w of warnings) {
      console.log(`  - ${w}`);
    }
  }

  if (errors.length > 0) {
    console.log('\n❌ Errors:');
    for (const e of errors) {
      console.log(`  - ${e}`);
    }
    process.exit(1);
  } else {
    console.log('\n✅ All validation checks passed!');
    process.exit(0);
  }
}

main();