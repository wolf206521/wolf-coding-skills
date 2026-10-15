#!/usr/bin/env bash
# 安装本能力仓库的 Skills 到 DSH / Claude Code 的用户技能目录。
# 用法：
#   ./scripts/install.sh                 # 安装到 ~/.dsh/skills 与 ~/.claude/skills
#   ./scripts/install.sh --uninstall     # 卸载
#   ./scripts/install.sh --target ~/.trae/skills   # 指定目标（可重复）
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILLS_SRC="$REPO_ROOT/skills"
UNINSTALL=0
TARGETS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --uninstall) UNINSTALL=1; shift ;;
    --target) TARGETS+=("$2"); shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 2 ;;
  esac
done

if [[ ! -d "$SKILLS_SRC" ]]; then
  echo "未找到技能源目录: $SKILLS_SRC" >&2
  exit 1
fi

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  TARGETS+=("$HOME/.dsh/skills" "$HOME/.claude/skills")
fi

mapfile -t SKILL_DIRS < <(find "$SKILLS_SRC" -mindepth 2 -maxdepth 2 -name SKILL.md -printf '%h\n' | sort)

if [[ ${#SKILL_DIRS[@]} -eq 0 ]]; then
  echo "skills 目录下未找到任何含 SKILL.md 的技能。"
  exit 0
fi

for dest in "${TARGETS[@]}"; do
  echo "== 目标：$dest"
  mkdir -p "$dest"
  for src in "${SKILL_DIRS[@]}"; do
    name="$(basename "$src")"
    dst="$dest/$name"
    if [[ $UNINSTALL -eq 1 ]]; then
      if [[ -e "$dst" ]]; then
        rm -rf "$dst"
        echo "  - 卸载 $name"
      else
        echo "  - $name 未安装，跳过"
      fi
      continue
    fi
    rm -rf "$dst"
    cp -R "$src" "$dst"
    echo "  + 安装 $name"
  done
done

if [[ $UNINSTALL -eq 1 ]]; then
  echo -e "\n卸载完成。"
else
  echo -e "\n安装完成。重新开启 Agent 会话后，描述任务即可自动触发对应技能。"
fi
