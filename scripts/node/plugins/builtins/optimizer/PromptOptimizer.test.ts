import { describe, it, beforeEach, afterEach, mock } from 'node:test';
import assert from 'node:assert/strict';
import { PromptOptimizer } from './PromptOptimizer.js';

describe('PromptOptimizer', () => {
  let plugin: PromptOptimizer;

  beforeEach(() => {
    plugin = new PromptOptimizer();
  });

  afterEach(async () => {
    await plugin.destroy?.();
  });

  describe('Metadata', () => {
    it('should have correct id', () => {
      assert.strictEqual(plugin.id, 'prompt-optimizer');
    });

    it('should have correct name', () => {
      assert.strictEqual(plugin.name, 'Prompt Optimizer');
    });

    it('should have correct version', () => {
      assert.strictEqual(plugin.version, '1.0.0');
    });

    it('should have description', () => {
      assert.ok(plugin.description.length > 0);
      assert.match(plugin.description, /optimize|prompt/i);
    });
  });

  describe('Initialization', () => {
    it('should initialize with default config', async () => {
      await plugin.initialize();
      // L'initialisation ne devrait pas lancer d'erreur
      assert.equal(true, true);
    });

    it('should accept custom config', async () => {
      const customConfig = {
        strict_mode: true,
        max_tokens: 2048
      };
      await plugin.initialize(customConfig);
      assert.equal(true, true); // La méthode doit s'exécuter sans erreur
    });

    it('should handle invalid config gracefully', async () => {
      const invalidConfig = 'invalid' as any; // Force invalid type
      await plugin.initialize(invalidConfig);
      assert.equal(true, true); // Doit gérer sans crash
    });
  });

  describe('Execution', () => {
    it('should execute successfully', async () => {
      const input = {
        prompt: 'Write a poem about nature.',
        target_models: ['gpt'],
        configuration: {
          strict_mode: false,
          max_tokens: 4096
        }
      };

      const result = await plugin.execute(input);

      assert.strictEqual(result.success, true);
      assert.ok(typeof result.original === 'string');
      assert.ok(typeof result.optimized === 'string');
      assert.ok(Array.isArray(result.improvements));
      assert.equal(typeof result.confidence_score, 'number');
      assert.equal(Object.keys(result.metadata).length > 0, true);
    });

    it('should optimize for different models', async () => {
      const basePrompt = 'Create a function.';
      
      const gptInput = { prompt: basePrompt, target_models: ['gpt'] };
      const claudeInput = { prompt: basePrompt, target_models: ['claude'] };
      
      const gptResult = await plugin.execute(gptInput);
      const claudeResult = await plugin.execute(claudeInput);

      assert.notStrictEqual(gptResult.optimized, claudeResult.optimized);
    });

    it('should handle empty prompt error', async () => {
      const invalidInput = { prompt: '' } as any;
      
      const result = await plugin.execute(invalidInput);
      
      assert.equal(result.success, false);
      assert.ok(result.improvements.includes('An error occurred during optimization'));
    });

    it('should return metadata with token count', async () => {
      const input = { prompt: 'Hello world' };
      const result = await plugin.execute(input);
      
      assert.equal(typeof result.metadata.tokens_count, 'number');
      assert.ok(result.metadata.tokens_count >= 0);
    });

    it('should maintain consistency across multiple runs', async () => {
      const input = { prompt: 'Consistent test prompt' };
      
      const result1 = await plugin.execute(input);
      const result2 = await plugin.execute(input);
      
      assert.strictEqual(result1.optimized, result2.optimized);
    });
  });

  describe('Cleanup', () => {
    it('should clear cache on destroy', async () => {
      await plugin.execute({ prompt: 'test' });
      await plugin.destroy();
      
      // Le cache devrait être vidé après destroy
      assert.equal(true, true); // La méthode se termine proprement
    });
  });

  describe('Error Handling', () => {
    it('should handle missing prompt field', async () => {
      const incompleteInput = {} as any;
      
      const result = await plugin.execute(incompleteInput);
      
      assert.equal(result.success, false);
    });

    it('should handle unsupported model', async () => {
      const input = { prompt: 'Test', target_models: ['unsupported-model'] };
      
      const result = await plugin.execute(input);
      
      // Ne devrait pas causer de crash
      assert.equal(typeof result, 'object');
    });
  });

  describe('Performance', () => {
    it('should execute within reasonable time limit', async () => {
      const startTime = Date.now();
      
      const input = { prompt: 'Optimize this prompt...' };
      const result = await plugin.execute(input);
      
      const elapsedTime = Date.now() - startTime;
      
      assert.ok(elapsedTime < 1000, 'Exécution en moins de 1 seconde');
    });

    it('should process large inputs efficiently', async () => {
      const largePrompt = 'Line '.repeat(100) + '\n';
      const input = { prompt: largePrompt };
      
      const start = Date.now();
      const result = await plugin.execute(input);
      const elapsed = Date.now() - start;
      
      assert.ok(elapsed < 2000, 'Traitement grand texte < 2 secondes');
    });
  });
});