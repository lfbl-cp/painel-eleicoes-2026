# data-raw/ref

Tabelas de referência pequenas e estáveis, versionadas no git (ao contrário do
resto de `data-raw/` e `data/`, que são gerados/baixados e ignorados pelo git).

- `linkador_bases.xlsx` — **já fornecido pelo usuário** (não precisa ser
  construído). Crosswalk nacional (5.570 municípios, aba `Sheet1`) com
  `id_TSE`, `id_munic_7` (código IBGE de 7 dígitos), `id_munic_6`, `id_RF`,
  `id_BCB`, `municipio`, `id_estado`, `estado_abrev`, `estado`, e flags de
  existência histórica (`existia_1991/2000/2010`, `existe`). A coluna
  `id_TSE` casa diretamente com o código de município usado nos arquivos do
  TSE — elimina a necessidade do join por nome (frágil a acentuação/grafia)
  usado no protótipo antigo. `R/04_crosswalk.R` (Fase 3) lê este arquivo
  direto com `readxl::read_excel()` e seleciona/renomeia só as colunas
  necessárias (`id_TSE`, `id_munic_7`, `estado_abrev`) — não precisa gerar
  um CSV derivado separado a menos que a leitura do xlsx no pipeline se
  mostre um problema.
- `partidos_cores.csv` — a criar na Fase 4. Sigla do partido → cor hex.
  Partidos não catalogados recebem cor determinística gerada por hash da
  sigla (`R/06_cores.R`), que é persistida de volta aqui.
- `candidatos_cores_override.csv` — a criar na Fase 4, opcional, vazio por
  padrão. Permite fixar a cor de um candidato específico em vez da cor
  padrão do partido.

Essas tabelas não devem precisar de mudanças estruturais em 2026 — só uma
sigla de partido nova ou um município eventualmente redivido exigiria uma
linha adicional.
