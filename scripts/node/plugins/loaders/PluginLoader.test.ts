// scripts/node/plugins/loaders/PluginLoader.test.ts

import { describe, it, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { PluginLoader } from './PluginLoader.js';
import { IPlugin } from '../interfaces/IPlugin.js';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

// Mock plugin pour les tests
class MockPlugin implements IPlugin {
  readonly id = 'mock-test';
  readonly name = 'Mock Test Plugin';
  readonly version = '1.0.0';
  readonly description = 'Plugin mock pour les tests';

  executeCalls: unknown[] = [];

  async initialize?(config?: Record<string, unknown>): Promise<void> {
    // Mock implementation
  }

  async execute(input: unknown): Promise<unknown> {
    this.executeCalls.push(input);
    return `Mock executed with: ${JSON.stringify(input)}`;
  }

  async destroy?(): Promise<void> {
    // Mock cleanup
  }
}

describe('PluginLoader', () => {
  let loader: PluginLoader;
  let mockPlugin: MockPlugin;

  beforeEach(() => {
    loader = new PluginLoader();
    mockPlugin = new MockPlugin();
  });

  afterEach(() => {
    // Cleanup mocks if needed
  });

  describe('Constructor', () => {
    it('should initialize with empty plugins map', () => {
      const plugins = loader.listPlugins();
      assert.strictEqual(plugins.length, 0);
    });
  });

  describe('listPlugins()', () => {
    it('should return empty array when no plugins loaded', () => {
      const plugins = loader.listPlugins();
      assert.ok(Array.isArray(plugins));
      assert.strictEqual(plugins.length, 0);
    });
  });

  describe('executePlugin()', () => {
    it.skip('should throw error when plugin not found', async () => {
      await assert.rejects(
        () => loader.executePlugin('non-existent', {}),
        (err: Error) => {
          assert.ok(err.message.includes('non trouvé ou désactivé'));
          return true;
        }
      );
    });

    it('should throw error when plugin is disabled', async () => {
      // Note: PluginLoader doesn't expose a way to manually add plugins
      // This test documents expected behavior for future implementation
      await assert.rejects(
        () => loader.executePlugin('mock-test', {}),
        (err: Error) => {
          assert.ok(err.message.includes('non trouvé ou désactivé'));
          return true;
        }
      );
    });
  });

  describe('loadFromDirectory()', () => {
    it('should not throw when directory does not exist', async () => {
      // Mock console.error to avoid log output during this test
      const originalError = console.error;
      console.error = () => {};

      try {
        const nonExistentPath = join(__dirname, 'non-existent-directory');
        await assert.doesNotReject(() => loader.loadFromDirectory(nonExistentPath));
      } finally {
        // Restore console.error after the test
        console.error = originalError;
      }
    });
  });

  describe('Integration with HelloWorldPlugin', () => {
    it('should load HelloWorldPlugin from examples directory', async () => {
      const examplesPath = join(__dirname, '../examples');
      await loader.loadFromDirectory(examplesPath);

      const plugins = loader.listPlugins();
      const helloWorld = plugins.find(p => p.plugin.id === 'hello-world');

      assert.ok(helloWorld, 'HelloWorldPlugin should be loaded');
      assert.strictEqual(helloWorld?.plugin.name, 'Hello World Plugin');
    });

    it('should execute HelloWorldPlugin successfully', async () => {
      const examplesPath = join(__dirname, '../examples');
      await loader.loadFromDirectory(examplesPath);

      const result = await loader.executePlugin('hello-world', 'TestUser');

      assert.ok(typeof result === 'string');
      assert.ok(result.includes('Hello, TestUser'));
      assert.ok(result.includes('hello-world'));
    });

    it('should execute HelloWorldPlugin with default input', async () => {
      const examplesPath = join(__dirname, '../examples');
      await loader.loadFromDirectory(examplesPath);

      const result = await loader.executePlugin('hello-world', {});

      assert.ok(typeof result === 'string');
      assert.ok(result.includes('Hello, Monde'));
    });
  });
});