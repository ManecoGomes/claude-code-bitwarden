#!/usr/bin/env bash
# Test suite for bwcc. Runs entirely offline: no Bitwarden account, no vault,
# no network. Vault-dependent behaviour is covered by docs/MANUAL-TESTS.md.
set -uo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BWCC="${BWCC:-$HERE/../plugins/bitwarden/bin/bwcc}"
PASS=0; FAIL=0

ok()   { printf '  ✓ %s\n' "$1"; PASS=$((PASS+1)); }
bad()  { printf '  ✗ %s\n     esperado: %s\n     obtido:   %s\n' "$1" "$2" "$3"; FAIL=$((FAIL+1)); }

eq() { # label expected actual
  if [ "$2" = "$3" ]; then ok "$1"; else bad "$1" "$2" "$3"; fi
}
contains() { # label needle haystack
  case "$3" in *"$2"*) ok "$1" ;; *) bad "$1" "contém '$2'" "$3" ;; esac
}
not_contains() { # label needle haystack
  case "$3" in *"$2"*) bad "$1" "NÃO contém '$2'" "$3" ;; *) ok "$1" ;; esac
}

T() { "$BWCC" __test "$@"; }

ITEM='{"id":"3f1a","name":"GitHub","type":1,
 "notes":"nota privada",
 "login":{"username":"maneco","password":"s3nh4-top","totp":"JBSWY3DPEHPK3PXP",
          "uris":[{"uri":"https://github.com/login"}]},
 "fields":[{"name":"api_key","type":1,"value":"k-123"},
           {"name":"ambiente","type":0,"value":"prod"}]}'

echo "bwcc — testes offline"
echo
echo "superfície do CLI"
eq "--version imprime a versão" "bwcc 0.1.1" "$("$BWCC" --version)"
contains "--help documenta o run" "bwcc run" "$("$BWCC" --help)"
out="$("$BWCC" comando-que-nao-existe 2>&1)"; rc=$?
eq   "comando inválido sai com erro" "1" "$rc"
contains "comando inválido explica" "comando desconhecido" "$out"

echo
echo "referências bw://"
eq "campo padrão é password" "GitHub|password" "$(T split_ref 'bw://GitHub' | tr '\t' '|')"
eq "campo explícito"         "GitHub|username" "$(T split_ref 'bw://GitHub/username' | tr '\t' '|')"
eq "nome com espaço"         "Supabase MGE|password" "$(T split_ref 'bw://Supabase MGE' | tr '\t' '|')"
eq "campo com espaço"        "Item|connection string" "$(T split_ref 'bw://Item/connection string' | tr '\t' '|')"
contains "sem esquema é rejeitado" "referência inválida" "$(T split_ref 'GitHub/password' 2>&1)"
contains "referência vazia é rejeitada" "referência" "$(T split_ref 'bw://' 2>&1)"

echo
echo "classificação de campos"
for f in password notes totp api_key; do
  if T field_is_secret "$ITEM" "$f"; then ok "$f é secreto"; else bad "$f é secreto" "secreto" "aberto"; fi
done
for f in username uri name id ambiente; do
  if T field_is_secret "$ITEM" "$f"; then bad "$f é aberto" "aberto" "secreto"; else ok "$f é aberto"; fi
done

echo
echo "extração de campos"
eq "username"      "maneco"                    "$(T item_field "$ITEM" username)"
eq "uri"           "https://github.com/login"  "$(T item_field "$ITEM" uri)"
eq "notes"         "nota privada"              "$(T item_field "$ITEM" notes)"
eq "campo custom aberto"  "prod"               "$(T item_field "$ITEM" ambiente)"
eq "campo custom oculto"  "k-123"              "$(T item_field "$ITEM" api_key)"
contains "campo inexistente falha" "vazio ou inexistente" "$(T item_field "$ITEM" nao_existe 2>&1)"

echo
echo "não divulgação"
masked="$(T mask_value 's3nh4-top')"
not_contains "máscara não contém o segredo" "s3nh4-top" "$masked"
contains     "máscara informa o tamanho"    "9 chars"   "$masked"
contains     "máscara traz fingerprint"     "sha256:"   "$masked"
eq "fingerprint é estável" "$(T fingerprint abc)" "$(T fingerprint abc)"
if [ "$(T fingerprint abc)" = "$(T fingerprint abd)" ]; then
  bad "fingerprints diferem por valor" "diferentes" "iguais"
else ok "fingerprints diferem por valor"; fi

echo
echo "sessão a partir de saída suja de pty"
key="AbC123+/defGHIjklMNOpqrSTUvwxYZ0123456789abcdefghijKLMNOPqrstuvwxyz0123456789AB=="
dirty="$(printf '\033[32m? Master password:\033[0m \r\nUnlocking...\r\n%s\r\n' "$key")"
eq "chave extraída de ANSI+CR" "$key" "$(printf '%s' "$dirty" | T extract_session)"
eq "sem chave devolve vazio"   ""     "$(printf 'erro qualquer\r\n' | T extract_session)"

echo
echo "flag biometrics-sdk-ipc (regressão: jq trata false como ausente)"
fx_false="$(mktemp)"; fx_true="$(mktemp)"; fx_none="$(mktemp)"
cat >"$fx_false" <<'J'
{"global_config_byServer":{"https://api.bitwarden.com":{"featureStates":{"outra":true,"biometrics-sdk-ipc":false}}}}
J
cat >"$fx_true" <<'J'
{"user_x_config_serverConfig":{"featureStates":{"biometrics-sdk-ipc":true}}}
J
printf '{"featureStates":{"outra-flag":true}}\n' >"$fx_none"
eq "false é lido como false (não como ausente)" "false" "$(T biometrics_flag "$fx_false")"
eq "true é lido como true"                      "true"  "$(T biometrics_flag "$fx_true")"
eq "sem a flag -> desconhecida"      "desconhecida" "$(T biometrics_flag "$fx_none")"
eq "arquivo inexistente -> desconhecida" "desconhecida" "$(T biometrics_flag /nao/existe)"
eq "primeiro arquivo sem a flag, segundo com" "false" "$(T biometrics_flag "$fx_none" "$fx_false")"
rm -f "$fx_false" "$fx_true" "$fx_none"

echo
echo "guardas do inject"
tpl="$(mktemp)"; printf 'A={{ bw://X/password }}\n' >"$tpl"
contains "inject exige destino" "informe -o" "$("$BWCC" inject -i "$tpl" 2>&1)"
contains "inject valida o modelo" "não encontrado" "$("$BWCC" inject -i /nao/existe -o /tmp/x 2>&1)"
rm -f "$tpl"

echo
echo "guardas do run e do add"
contains "run exige comando" "uso: bwcc run" "$("$BWCC" run 2>&1)"
contains "add exige origem da senha" "--generate ou --password-stdin" \
  "$(BWCC_SESSION_STORE=none "$BWCC" add teste-xyz --username u 2>&1 | tail -1)"

echo
printf '%d ok, %d falha(s)\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
