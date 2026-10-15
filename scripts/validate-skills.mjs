#!/usr/bin/env node
/**
 * validate-skills.mjs
 * 校验本能力仓库的完整性：
 *   1. skills/ 下每个技能目录的 SKILL.md 含合法 YAML frontmatter（name/description），且 name === 目录名。
 *   2. docs/*.md 与根 README、skills/README 中的相对 Markdown 链接指向真实存在的文件（死链检测）。
 *   3. 技能目录数统计（含自研 wolf-* 与 vendor 第三方技能）。
 *
 * 用法： node scripts/validate-skills.mjs
 * 退出码： 0 = 通过； 1 = 存在错误。
 */
import { readdirSync, readFileSync, statSync, existsSync } from 'node:fs';
import { join, dirname, resolve, relative, normalize } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const ROOT = resolve(__dirname, '..');
const SKILLS_DIR = join(ROOT, 'skills');
const DOCS_DIR = join(ROOT, 'docs');

let errors = [];
let warnings = [];

function readText(p) {
  return readFileSync(p, 'utf8');
}

function listDirs(dir) {
  return readdirSync(dir).filter((n) => {
    try { return statSync(join(dir, n)).isDirectory(); } catch { return false; }
  });
}

function parseFrontmatter(text) {
  if (!text.startsWith('---')) return null;
  const end = text.indexOf('\n---', 3);
  if (end === -1) return null;
  const body = text.slice(4, end);
  const fm = {};
  for (const line of body.split('\n')) {
    const m = line.match(/^([A-Za-z0-9_-]+):\s*(.*)$/);
    if (m) fm[m[1]] = m[2].trim();
  }
  return fm;
}

// ---- 1. 校验 skills（动态枚举，不硬编码清单）----
const skillDirs = listDirs(SKILLS_DIR).filter((n) => n !== 'README.md');
for (const s of skillDirs) {
  const skillMd = join(SKILLS_DIR, s, 'SKILL.md');
  if (!existsSync(skillMd)) {
    errors.push(`skills/${s} 缺少 SKILL.md`);
    continue;
  }
  const text = readText(skillMd);
  const fm = parseFrontmatter(text);
  if (!fm) {
    errors.push(`skills/${s}/SKILL.md 无合法 YAML frontmatter`);
    continue;
  }
  if (!fm.name) errors.push(`skills/${s}/SKILL.md 缺少 name 字段`);
  else if (fm.name !== s) errors.push(`skills/${s}/SKILL.md 的 name(${fm.name}) 与目录名(${s}) 不一致`);
  if (!fm.description) errors.push(`skills/${s}/SKILL.md 缺少 description 字段`);
}

// ---- 2. 死链检测（docs 与根 README、skills/README）----
const mdFiles = [];
for (const f of readdirSync(DOCS_DIR)) {
  if (f.endsWith('.md')) mdFiles.push(join(DOCS_DIR, f));
}
mdFiles.push(join(ROOT, 'README.md'));
mdFiles.push(join(SKILLS_DIR, 'README.md'));

const linkRe = /\[[^\]]*\]\(([^)#\s]+)(?:#[^)]*)?\)/g;
for (const md of mdFiles) {
  const text = readText(md);
  let m;
  while ((m = linkRe.exec(text)) !== null) {
    let target = m[1];
    if (target.startsWith('http://') || target.startsWith('https://')) continue;
    if (target.startsWith('mailto:')) continue;
    target = target.replace(/^\.\//, '');
    const abs = normalize(resolve(dirname(md), target));
    if (!existsSync(abs)) {
      errors.push(`死链: ${relative(ROOT, md)} -> ${target}`);
    }
  }
}

// ---- 输出 ----
console.log(`\n=== validate-skills 校验结果 ===`);
console.log(`技能目录数: ${skillDirs.length}`);
console.log(`文档文件数: ${mdFiles.length}`);
if (warnings.length) {
  console.log(`\n[警告] ${warnings.length} 条：`);
  warnings.forEach((w) => console.log('  ⚠ ' + w));
}
if (errors.length) {
  console.log(`\n[错误] ${errors.length} 条：`);
  errors.forEach((e) => console.log('  ✗ ' + e));
  console.log('\n校验失败。请修复上述问题后重试。');
  process.exit(1);
} else {
  console.log('\n✔ 全部校验通过。');
  process.exit(0);
}
