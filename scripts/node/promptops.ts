#!/usr/bin/env node
/**
 * PromptOps Node Utility
 * License: MIT
 * @author: valorisa
 * TODO(v2): Add support for JSON Schema validation.
 * TODO(v2): Implement npm publish workflow.
 */

import { PluginLoader } from './plugins/loaders/PluginLoader.js';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ARGS = process.argv.slice(2);

function showHelp() {
    console.log('PromptOps Node Utility v1.0.0');
    console.log('Usage: node promptops.js [command]');
    console.log('');
    console.log('Commands:');
    console.log('  run <plugin> [options]  Exécute un plugin');
    console.log('  list                    Liste les plugins disponibles');
    console.log('  help                    Affiche cette aide');
    console.log('  version                 Affiche la version');
}

async function runPlugin(pluginId, options) {
    const loader = new PluginLoader();
    
    // Charge les plugins depuis le dossier builtins
    const builtinsPath = join(__dirname, 'plugins', 'builtins');
    await loader.loadFromDirectory(builtinsPath);
    
    // Charge les plugins depuis le dossier examples
    const examplesPath = join(__dirname, 'plugins', 'examples');
    await loader.loadFromDirectory(examplesPath);
    
    // Exécute le plugin
    try {
        const result = await loader.executePlugin(pluginId, options);
        console.log(result);
    } catch (error) {
        console.error(`❌ Erreur: ${error.message}`);
        process.exit(1);
    }
}

async function listPlugins() {
    const loader = new PluginLoader();
    
    const builtinsPath = join(__dirname, 'plugins', 'builtins');
    await loader.loadFromDirectory(builtinsPath);
    
    const examplesPath = join(__dirname, 'plugins', 'examples');
    await loader.loadFromDirectory(examplesPath);
    
    const plugins = loader.listPlugins();
    console.log('Plugins disponibles:');
    plugins.forEach(p => {
        console.log(`  - ${p.plugin.id} (${p.plugin.name} v${p.plugin.version})`);
    });
}

async function main() {
    const command = ARGS[0];
    
    switch (command) {
        case 'run':
            const pluginId = ARGS[1];
            if (!pluginId) {
                console.error('❌ Erreur: Plugin ID requis');
                console.error('Usage: node promptops.js run <plugin-id>');
                process.exit(1);
            }
            const options = {};
            // Parse les options --key=value ou --key
            for (let i = 2; i < ARGS.length; i++) {
                if (ARGS[i].startsWith('--')) {
                    const arg = ARGS[i].slice(2);
                    const [key, value] = arg.split('=');
                    options[key] = value || true;
                }
            }
            await runPlugin(pluginId, options);
            break;
            
        case 'list':
            await listPlugins();
            break;
            
        case 'help':
            showHelp();
            break;
            
        case 'version':
            console.log('1.0.0');
            break;
            
        default:
            showHelp();
            break;
    }
}

main().then(() => process.exit(0)).catch(() => process.exit(1));