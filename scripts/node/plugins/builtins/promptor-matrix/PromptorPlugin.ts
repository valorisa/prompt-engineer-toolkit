// scripts/node/plugins/builtins/PromptorPlugin.ts

import { IPlugin } from '../interfaces/IPlugin.js';
import { readFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export class PromptorPlugin implements IPlugin {
  readonly id = 'promptor-matrix';
  readonly name = 'Promptor Matrix';
  readonly version = '1.0.0';
  readonly description = 'Matrice de prompt pour Reverse Prompt Engineering — Génère des prompts optimisés 5 étoiles';
  
  private matrix: string = '';
  
  /**
   * Initialisation : charge la matrice depuis le fichier config
   */
  async initialize(): Promise<void> {
    try {
      const matrixPath = join(__dirname, '../../config/system-prompts/promptor-matrix.md');
      this.matrix = await readFile(matrixPath, 'utf-8');
      console.log('✅ Promptor initialisé — matrice chargée');
    } catch (error) {
      console.error('❌ Échec chargement matrice Promptor:', error instanceof Error ? error.message : String(error));
      throw error;
    }
  }
  
  /**
   * Exécution : affiche la matrice pour l'utilisateur
   */
  async execute(input: unknown): Promise<{ success: boolean; matrix: string; instructions: string }> {
    await this.initialize();
    
    // En-tête
    console.log('\n' + '═'.repeat(60));
    console.log('🤖  PROMPTOR — Matrice de Reverse Prompt Engineering');
    console.log('═'.repeat(60) + '\n');
    
    // Affiche la matrice
    console.log(this.matrix);
    
    // Pied de page avec instructions
    console.log('\n' + '═'.repeat(60));
    console.log('📋  INSTRUCTIONS');
    console.log('═'.repeat(60));
    console.log('1. Copie cette matrice complète');
    console.log('2. Ouvre ton LLM préféré (Claude, GPT-4, Gemini, Qwen, etc.)');
    console.log('3. Colle la matrice comme SYSTEM PROMPT ou premier message');
    console.log('4. Suis les 3 étapes guidées par Promptor');
    console.log('5. À la fin, copie le prompt final 5 étoiles ★★★★★\n');
    
    return { 
      success: true, 
      matrix: String(this.matrix),
      instructions: 'Copier-coller dans ton LLM préféré'
    };
  }
  
  /**
   * Nettoyage (optionnel)
   */
  async destroy?(): Promise<void> {
    this.matrix = '';
    console.log('🧹 Promptor nettoyé');
  }
}

// ============================================================================
// TEST DIRECT — Exécute le plugin quand ce fichier est lancé avec tsx
// ============================================================================

// Pour tester : npx tsx plugins/builtins/PromptorPlugin.ts
// Ce code s'exécute uniquement en mode test direct
const isDirectExecution = process.argv[1] === fileURLToPath(import.meta.url);

if (isDirectExecution) {
  (async () => {
    console.log('🚀 Lancement de PromptorPlugin en mode test...\n');
    
    const plugin = new PromptorPlugin();
    
    try {
      await plugin.execute({});
      console.log('\n✅ Test terminé avec succès');
      process.exit(0);
    } catch (error) {
      console.error('\n❌ Erreur lors du test:', error instanceof Error ? error.message : String(error));
      process.exit(1);
    }
  })();
}