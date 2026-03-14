// scripts/node/plugins/examples/hello-world/HelloWorldPlugin.ts

import { IPlugin } from '../../interfaces/IPlugin.js';

export class HelloWorldPlugin implements IPlugin {
  readonly id = 'hello-world';
  readonly name = 'Hello World Plugin';
  readonly version = '1.0.0';
  readonly description = 'Plugin exemple qui salue l\'utilisateur';

  async initialize(config?: Record<string, unknown>): Promise<void> {
    console.log(`👋 [${this.name}] initialisé`);
  }

  async execute(input: unknown): Promise<unknown> {
    const message = typeof input === 'string' ? input : 'Monde';
    return `🎉 Hello, ${message} ! (via plugin ${this.id})`;
  }

  async destroy(): Promise<void> {
    console.log(`👋 [${this.name}] nettoyé`);
  }
}