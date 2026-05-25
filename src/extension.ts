import * as fs from 'fs';
import * as path from 'path';
import * as vscode from 'vscode';
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export async function activate(ctx: vscode.ExtensionContext): Promise<void> {
  const binary = resolveBinary(ctx);
  if (!binary) {
    vscode.window.showErrorMessage(
      'dbml-tools binary not found. Set "dbml.path" or install dbml-tools on $PATH.'
    );
    return;
  }

  const cfg = vscode.workspace.getConfiguration('dbml');
  const args = ['lsp'];
  const logPath = cfg.get<string>('log.path', '');
  if (logPath) {
    args.push('--log', logPath);
  }

  const serverOpts: ServerOptions = {
    run: { command: binary, args },
    debug: { command: binary, args },
  };

  const clientOpts: LanguageClientOptions = {
    documentSelector: [{ scheme: 'file', language: 'dbml' }],
    synchronize: {
      fileEvents: vscode.workspace.createFileSystemWatcher('**/*.dbml'),
      configurationSection: 'dbml',
    },
    outputChannelName: 'DBML',
  };

  client = new LanguageClient('dbml', 'DBML Language Server', serverOpts, clientOpts);

  ctx.subscriptions.push(
    vscode.commands.registerCommand('dbml.restart', async () => {
      if (!client) return;
      await client.stop();
      await client.start();
      vscode.window.showInformationMessage('DBML language server restarted.');
    })
  );

  await client.start();
}

export function deactivate(): Thenable<void> | undefined {
  return client?.stop();
}

// ---------------------------------------------------------------------------
// Binary resolution
// ---------------------------------------------------------------------------

function resolveBinary(ctx: vscode.ExtensionContext): string | undefined {
  const cfg = vscode.workspace.getConfiguration('dbml');
  const configured = cfg.get<string>('path', '').trim();
  if (configured && fs.existsSync(configured)) {
    return configured;
  }
  // Check $PATH
  const onPath = findOnPath('dbml-tools');
  if (onPath) return onPath;

  // Check bundled (per-platform).
  const bundled = path.join(
    ctx.extensionPath,
    'server-bin',
    `${process.platform}-${process.arch}`,
    process.platform === 'win32' ? 'dbml-tools.exe' : 'dbml-tools'
  );
  if (fs.existsSync(bundled)) {
    try {
      if (process.platform !== 'win32') {
        fs.chmodSync(bundled, 0o755);
      }
    } catch {
      // ignore — will surface as spawn error
    }
    return bundled;
  }
  return undefined;
}

function findOnPath(name: string): string | undefined {
  const PATH = process.env.PATH || '';
  const sep = process.platform === 'win32' ? ';' : ':';
  const exe = process.platform === 'win32' ? `${name}.exe` : name;
  for (const dir of PATH.split(sep)) {
    if (!dir) continue;
    const full = path.join(dir, exe);
    if (fs.existsSync(full)) return full;
  }
  return undefined;
}
