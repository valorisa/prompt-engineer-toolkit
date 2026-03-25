// scripts/node/tests/integration/cli-flow.test.ts

import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);

describe('Integration: CLI Flow', () => {
  // Chemin vers le CLI (ajuste selon ton architecture)
  const CLI_PATH = 'tsx promptops.ts';

  describe('promptops run', () => {
    it('should execute hello-world plugin successfully', async () => {
      const { stdout } = await execAsync(`${CLI_PATH} run hello-world --name=TestUser`);  // ✅ Avec =
  
      assert.ok(stdout.includes('Hello') || stdout.includes('Monde'));  // ✅ Plus flexible
      assert.ok(stdout.includes('hello-world'));
    });

    it('should execute promptor-matrix plugin successfully', async () => {
      const { stdout } = await execAsync(`${CLI_PATH} run promptor-matrix`);
      
      assert.ok(stdout.includes('PROMPTOR'));
      assert.ok(stdout.includes('Matrice'));
      assert.ok(stdout.includes('Étape 1'));
    });

    it('should show error for unknown plugin', async () => {
      try {
        await execAsync(`${CLI_PATH} run unknown-plugin`);
        assert.fail('Should have thrown an error');
      } catch (error: any) {
        assert.ok(
          error.stderr.includes('non trouvé') || 
          error.stderr.includes('inconnu') ||
          error.stderr.includes('not found')
        );
      }
    });
  });
});