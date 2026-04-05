// scripts/node/plugins/builtins/PromptorPlugin.test.ts

import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { PromptorPlugin } from './PromptorPlugin.js';

describe('PromptorPlugin', () => {
  let plugin: PromptorPlugin;

  beforeEach(() => {
    plugin = new PromptorPlugin();
  });

  afterEach(async () => {
    await plugin.destroy?.();
  });

  describe('Metadata', () => {
    it('should have correct id', () => {
      assert.strictEqual(plugin.id, 'promptor-matrix');
    });

    it('should have correct name', () => {
      assert.strictEqual(plugin.name, 'Promptor Matrix');
    });

    it('should have correct version', () => {
      assert.strictEqual(plugin.version, '1.0.0');
    });

    it('should have description', () => {
      assert.ok(plugin.description.length > 0);
      assert.ok(plugin.description.includes('Reverse Prompt Engineering'));
    });
  });

  describe('initialize()', () => {
    it('should load matrix file without throwing', async () => {
      await assert.doesNotReject(() => plugin.initialize());
    });

    it('should populate matrix property after initialize', async () => {
      await plugin.initialize();
      assert.ok(plugin['matrix'].length > 0);
      assert.ok(plugin['matrix'].includes('Promptor'));
      assert.ok(plugin['matrix'].includes('Étape 1'));
    });
  });

  describe('execute()', () => {
    it('should return success result', async () => {
      const result = await plugin.execute({});
      assert.ok(typeof result === 'object');
      assert.ok(result !== null);
      const obj = result as Record<string, unknown>;
      assert.strictEqual(obj.success, true);
    });

    it('should return matrix in result', async () => {
      const result = await plugin.execute({});
      const obj = result as Record<string, unknown>;
      assert.ok(typeof obj.matrix === 'string');
      assert.ok((obj.matrix as string).length > 0);
    });

    it('should return instructions in result', async () => {
      const result = await plugin.execute({});
      const obj = result as Record<string, unknown>;
      assert.ok(typeof obj.instructions === 'string');
      assert.ok((obj.instructions as string).includes('Copier-coller'));
    });
  });

  describe('destroy()', () => {
    it('should clear matrix without throwing', async () => {
      await plugin.initialize();
      await assert.doesNotReject(() => plugin.destroy?.());
    });
  });
});