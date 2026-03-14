// scripts/node/plugins/interfaces/IPlugin.ts

/**
 * Interface de base pour tous les plugins du prompt-engineer-toolkit
 */
export interface IPlugin {
  /** Identifiant unique du plugin */
  readonly id: string;
  
  /** Nom affiché */
  readonly name: string;
  
  /** Version du plugin (semver) */
  readonly version: string;
  
  /** Description courte */
  readonly description: string;
  
  /**
   * Initialisation du plugin (appelée au chargement)
   * @returns Promise résolue quand le plugin est prêt
   */
  initialize?(config?: Record<string, unknown>): Promise<void>;
  
  /**
   * Point d'entrée principal du plugin
   * @param input - Données d'entrée du prompt
   * @returns Résultat transformé
   */
  execute(input: unknown): Promise<unknown>;
  
  /**
   * Nettoyage avant déchargement (optionnel)
   */
  destroy?(): Promise<void>;
}

/**
 * Métadonnées pour le registre de plugins
 */
export interface PluginManifest {
  plugin: IPlugin;
  path: string;
  enabled: boolean;
  dependencies?: string[];
}