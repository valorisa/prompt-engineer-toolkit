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
   * @param config Options personnalisées du plugin
   * @returns Promise résolue quand le plugin est prêt
   */
  initialize?(config?: Record<string, unknown>): Promise<void>;

  /** 
   * Point d'entrée principal du plugin
   * @param input Données d'entrée du prompt
   * @returns Résultat transformé ou optimisé
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

/**
 * Résultat d'optimisation de prompt
 */
export interface OptimizationResult {
  success: boolean;
  original: string;
  optimized: string;
  improvements: string[];
  confidence_score: number; // entre 0 et 1
  target_model?: string;    // modèle cible si spécifié
  metadata: {
    processing_time_ms: number;
    tokens_count?: number;
    quality_checks_passed: number;
  };
}

/**
 * Entrée attendue par le plugin Optimizer
 */
export interface OptimizeInput {
  prompt: string;
  target_models?: string[]; // ex: ['gpt', 'claude', 'gemini']
  configuration?: {
    strict_mode?: boolean;
    max_tokens?: number;
    temperature?: number;
  };
}