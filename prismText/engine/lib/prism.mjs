// Un prisme = un fichier markdown : frontmatter (id, version, description,
// entrees) + corps (le prompt de transformation). Son empreinte SHA-256 est
// tamponnee dans chaque resultat : on sait toujours quel prompt, dans quelle
// version exacte, a produit quel texte.

import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

export function loadPrism(path) {
  const raw = readFileSync(path, 'utf8');
  const m = raw.match(/^---\n([\s\S]*?)\n---\n([\s\S]*)$/);
  if (!m) throw new Error(`${path} : frontmatter "---" manquant`);
  const meta = {};
  for (const line of m[1].split('\n')) {
    const kv = line.match(/^([a-z_]+):\s*(.*)$/);
    if (kv) meta[kv[1]] = kv[2].replace(/^["']|["']$/g, '');
  }
  for (const k of ['id', 'version', 'description']) {
    if (!meta[k]) throw new Error(`${path} : champ "${k}" manquant dans le frontmatter`);
  }
  if (!/^\d+\.\d+\.\d+$/.test(meta.version)) throw new Error(`${path} : version "${meta.version}" non semver`);
  return {
    id: meta.id,
    version: meta.version,
    description: meta.description,
    entrees: meta.entrees ? meta.entrees.split(',').map((s) => s.trim()).filter(Boolean) : [],
    body: m[2].trim(),
    sha256: createHash('sha256').update(raw).digest('hex'),
    path,
  };
}

export function stamp(prism) {
  return { id: prism.id, version: prism.version, sha256: prism.sha256 };
}
