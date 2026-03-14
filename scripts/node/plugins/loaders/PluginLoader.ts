// scripts/node/plugins/loaders/PluginLoader.ts

import { IPlugin, PluginManifest } from '../interfaces/IPlugin.js';
import { readdir } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));

export class PluginLoader {
  private plugins: Map<string, PluginManifest> = new Map();

  /**
   * Charge tous les plugins depuis un dossier
   */
  async loadFromDirectory(directory: string): Promise<void> {
    try {
      const entries = await readdir(directory, { withFileTypes: true });
      
      for (const entry of entries) {
        if (entry.isDirectory()) {
          await this.loadPlugin(join(directory, entry.name));
        }
      }
    } catch (error) {
      console.error('❌ Erreur chargement directory:', error);
    }
  }

  /**
   * Charge un plugin individuel
   */
  private async loadPlugin(pluginPath: string): Promise<void> {
    try {
      // TODO: Implémenter le chargement dynamique avec import()
      console.log(`🔌 Plugin chargé : ${pluginPath}`);
    } catch (error) {
      console.error(`❌ Échec chargement plugin ${pluginPath}:`, error);
    }
  }

  /**
   * Exécute un plugin par son ID
   */
  async executePlugin(pluginId: string, input: unknown): Promise<unknown> {
    const manifest = this.plugins.get(pluginId);
    if (!manifest?.enabled) {
      throw new Error(`Plugin "${pluginId}" non trouvé ou désactivé`);
    }
    return await manifest.plugin.execute(input);
  }

  /**
   * Liste les plugins disponibles
   */
  listPlugins(): PluginManifest[] {
    return Array.from(this.plugins.values());
  }
}