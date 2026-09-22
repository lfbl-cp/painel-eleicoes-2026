# Painel Eleições — CLAUDE.md

## Propósito

Painel público, interativo, de resultados eleitorais municipais do Brasil
(presidente, governador, senador — 1º e 2º turno), cobrindo as 27 UFs. Usa
dados de 2022 como piloto/placeholder até a divulgação dos dados de 2026;
trocar de eleição é reexecutar o pipeline com outro `--ano`, sem mudar
arquitetura.

Evolução de um protótipo estático em R (`C:\Users\felip\Desktop\Mapas
eleitorais R`), que cobria só Pernambuco com um script por combinação
cargo/turno/UF, candidatos e cores hardcoded, e mapas estáticos em PNG. Este
projeto generaliza isso para um pipeline parametrizado e um painel web
interativo.

## Decisões de arquitetura (e o porquê)

- **R (tidyverse, sf, geobr, spdep)** para todo o pipeline de dados —
  continuidade com o que já foi validado no protótipo, sem curva de
  aprendizado nova.
- **Fonte de dados TSE: "votação por candidato, município e zona"**, não
  "votação por seção" (usada no protótipo antigo). O nível de seção é
  centenas de MB por estado e desnecessário para mapas por município; o
  agregado por município/zona é ordens de magnitude menor e suficiente para
  tudo que o painel mostra.
- **Front-end estático (HTML/JS + Leaflet + TopoJSON), não Shiny hospedado.**
  O painel é público. Recalcular um mapa de 5.570 municípios a cada
  interação de usuário via servidor Shiny seria caro (cota de horas em
  shinyapps.io ou custo de VPS) e lento sob tráfego real. Em vez disso, R
  faz todo o processamento pesado (dados, join geográfico, LISA) **uma
  única vez** por eleição e exporta arquivos pré-computados; o navegador só
  lê e filtra, sem servidor.
- **Join geográfico por código IBGE, não por nome de município.** O
  protótipo antigo fazia join por nome (`NM_MUNICIPIO`), frágil a acento e
  grafia. Agora usa `data-raw/ref/linkador_bases.xlsx` — crosswalk nacional
  (5.570 municípios) já fornecido pelo usuário, com `id_TSE` casando direto
  com o código de município do TSE e `id_munic_7` como código IBGE de 7
  dígitos. Ver `data-raw/ref/README.md` para as colunas.
- **Cor por partido derivada de tabela + fallback automático**, em vez do
  `case_when` manual por eleição do protótipo antigo. Partido não
  catalogado recebe cor determinística por hash da sigla.
- **Camada de aquisição de dados desacoplada do resto do pipeline**, com
  fallback manual — ver seção abaixo.

## Nota operacional: bloqueio de downloads do TSE (defeso eleitoral)

Em períodos próximos a eleições (defeso eleitoral), o portal
`dadosabertos.tse.jus.br` pode bloquear downloads automatizados. A função
`obter_dados_tse(ano, uf)` (em `R/01_aquisicao.R`) trata isso assim:

1. Verifica primeiro se o arquivo já existe em
   `data-raw/downloads/{ano}/votacao_candidato_munzona/`.
2. Se não existir, tenta baixar automaticamente via `httr2`.
3. Se o download falhar (403/429/timeout — sintomas do bloqueio), a função
   **não trava com erro genérico**: aborta com uma mensagem indicando a URL
   do portal e o caminho exato onde salvar o arquivo, e grava um
   `README_DOWNLOAD_MANUAL.md` na pasta de destino.
4. Nesse caso, baixe o ZIP manualmente pelo navegador em
   dadosabertos.tse.jus.br e salve em
   `data-raw/downloads/{ano}/votacao_candidato_munzona/`. O restante do
   pipeline não diferencia arquivo baixado manualmente de automático.

## Estrutura de pastas

```
config/            parametros.yml — parâmetros padrão do pipeline
data-raw/ref/      tabelas de referência pequenas, versionadas (crosswalk, cores)
data-raw/downloads/{ano}/   ZIPs/CSVs do TSE, gitignored
data/interim/{ano}/         dados limpos em parquet, gitignored
data/processed/{ano}/       dados agregados prontos (rds), gitignored
output/geo/         TopoJSON (nacional + por UF), versionado — é o que o site serve
output/results/{ano}/       JSON de atributos por cargo/turno/candidato, versionado
output/index.json   metadados que populam os seletores do front-end
R/                  funções do pipeline, uma etapa por arquivo numerado
pipeline/           run_pipeline.R — orquestração via linha de comando
frontend/           HTML/CSS/JS estático (sem build step)
tests/testthat/     testes unitários (crosswalk, cores, LISA)
```

`output/` é versionado no git (ao contrário de `data/` e
`data-raw/downloads/`) porque é o artefato que o GitHub Pages/Netlify serve
diretamente — não há passo de build separado.

## Convenções

- Funções em português, `snake_case`, padrão verbo_substantivo (`obter_`,
  `ler_`, `limpar_`, `calcular_`, `juntar_`, `exportar_`) — consistente com
  o protótipo original.
- Scripts em `R/` só definem funções (nunca rodam nada ao dar `source()`);
  orquestração fica isolada em `pipeline/run_pipeline.R`.
- Numeração dos arquivos em `R/` reflete a ordem do pipeline.

## Comandos

```
# Piloto (Pernambuco, dados de 2022)
Rscript pipeline/run_pipeline.R --ano=2022 --uf=PE

# Nacional
Rscript pipeline/run_pipeline.R --ano=2022 --uf=all

# 2026, quando os dados forem divulgados
Rscript pipeline/run_pipeline.R --ano=2026 --uf=all

# Setup do ambiente R
Rscript -e 'renv::restore()'
```

## Estado atual

Projeto em bootstrap (estrutura de pastas + configuração + `renv` validado,
incluindo `V8`/`rmapshaper` instalando corretamente via binário no Windows).
Pipeline em R (`R/`, `pipeline/`) e front-end (`frontend/`) ainda não
implementados — ver `C:\Users\felip\.claude\plans\proud-growing-metcalfe.md`
para o plano de fases completo (piloto em PE antes de escalar para as 27
UFs).

O crosswalk TSE↔IBGE (Fase 3 do plano) já está disponível em
`data-raw/ref/linkador_bases.xlsx` (fornecido pelo usuário, não precisa ser
construído do zero) — adicionar `readxl` à lista de pacotes do `renv` ao
implementar `R/04_crosswalk.R`.
