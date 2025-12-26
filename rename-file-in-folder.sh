#!/usr/bin/env zsh
set -euo pipefail

DIR="${1:-icons}"

if [[ ! -d "$DIR" ]]; then
  echo "Folder not found: $DIR" >&2
  exit 1
fi

# slugify: bỏ dấu -> ascii, space -> '-', bỏ ký tự lạ, gọn dấu '-', TitleCase từng từ
slugify_title() {
  local base="$1"

  # Bỏ dấu chuẩn bằng Python để tránh lỗi iconv với đ/Đ hoặc ký tự tổ hợp
  local s
  s="$(python3 - <<'PY' "$base"
import sys, unicodedata
s = sys.argv[1]
s = unicodedata.normalize('NFD', s)
s = ''.join(ch for ch in s if unicodedata.category(ch) != 'Mn')
s = s.replace('đ', 'd').replace('Đ', 'D')
print(s)
PY
)"

  # thay & thành 'and', còn lại: ký tự không phải chữ/số -> space
  s="${s//&/ and }"
  s="$(printf "%s" "$s" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+/ /g; s/^ +| +$//g; s/ +/ /g')"

  # TitleCase + join bằng '-': "ban lam viec" -> "Ban-Lam-Viec"
  local out=""
  local w
  for w in ${(s: :)s}; do
    out+="${(C)w}-"
  done
  out="${out%-}"
  printf "%s" "$out"
}

# chỉ xử lý png/jpg/jpeg/svg/webp
typeset -a exts
exts=(png jpg jpeg svg webp)

for ext in $exts; do
  for f in "$DIR"/*.$ext(N); do
    [[ -f "$f" ]] || continue

    filename="${f:t}"              # tên file
    name="${filename:r}"           # phần tên (không ext)
    ext2="${filename:e}"           # ext

    newbase="$(slugify_title "$name")"
    [[ -n "$newbase" ]] || continue

    newname="${newbase}.${ext2}"
    newpath="${DIR}/${newname}"

    if [[ "$f" == "$newpath" ]]; then
      continue
    fi

    # tránh đè file trùng tên
    if [[ -e "$newpath" ]]; then
      i=2
      while [[ -e "${DIR}/${newbase}-${i}.${ext2}" ]]; do
        ((i++))
      done
      newname="${newbase}-${i}.${ext2}"
      newpath="${DIR}/${newname}"
    fi

    echo "Rename: ${filename}  ->  ${newname}"
    mv -n -- "$f" "$newpath"
  done
done
