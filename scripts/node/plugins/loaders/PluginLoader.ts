// scripts/node/plugins/loaders/PluginLoader.ts

import { IPlugin, PluginManifest } from '../interfaces/IPlugin.js';
import { readdir } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath, pathToFileURL } from 'url';

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
    // 📁 Chemin vers le fichier principal du plugin
    const pluginFile = join(pluginPath, 'index.js');
    
    // 🔌 Import dynamique du module plugin
    // ⚠️ Sur Windows ESM, convertir le chemin en file:// URL
    const pluginUrl = pathToFileURL(pluginFile).href;
    const module = await import(pluginUrl);  // ← ✅ Corrigé pour Windows
      
      // 📦 Récupère la classe du plugin (export default ou premier export)
      const PluginClass = module.default || Object.values(module)[0];
      
      if (!PluginClass) {
        throw new Error(`Aucune classe de plugin exportée dans ${pluginFile}`);
      }
      
      // 🏗️ Instancie le plugin
      const pluginInstance: IPlugin = new PluginClass();
      
      // 📋 Crée le manifest SELON L'INTERFACE PluginManifest
      const manifest: PluginManifest = {
        plugin: pluginInstance,  // ← Obligatoire
        path: pluginPath,        // ← Obligatoire
        enabled: true,           // ← Obligatoire
        // dependencies: [],     // ← Optionnel, à ajouter si besoin
      };
      
      // 💾 Stocke dans la Map : clé = pluginInstance.id (de IPlugin)
      this.plugins.set(pluginInstance.id, manifest);
      
      // 🎉 Log avec les propriétés de pluginInstance (IPlugin)
      console.log(`✅ Plugin chargé : ${pluginInstance.name} v${pluginInstance.version}`);
      
    } catch (error) {
      console.error(`❌ Échec chargement plugin ${pluginPath}:`, error instanceof Error ? error.message : String(error));
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