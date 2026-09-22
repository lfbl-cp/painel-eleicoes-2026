# Painel Eleições — CLAUDE.md

## Propósito

Painel público, interativo, de resultados eleitorais do Brasil (presidente,
governador, senador — 1º e 2º turno), cobrindo as 27 UFs, com resultado
detalhado por município e agregação em microrregião, mesorregião e UF. Usa
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
- **Unidades de análise: município (base), microrregião, mesorregião e
  UF.** `geobr::read_municipality()` não traz código de meso/microrregião
  por município — só `read_meso_region()`/`read_micro_region()`, que dão
  os polígonos agregados sem o de-para. Em vez de depender de mais uma
  fonte externa (IBGE API, outro arquivo manual), o de-para
  município→meso/microrregião é **derivado por join espacial**
  (`sf::st_join()` do centroide do município contra os polígonos de
  meso/microrregião do `geobr`) — mesorregião e microrregião nunca cruzam
  fronteira de UF, então a correspondência é 1:1 sem ambiguidade.
  **LISA é só em nível de município** — microrregião/mesorregião/UF nunca
  entram no LISA, só nas visões de vencedor e candidato isolado contínuo.

## Nota operacional: bloqueio de downloads do TSE (defeso eleitoral)

Em períodos próximos a eleições (defeso eleitoral), o portal
`dadosabertos.tse.jus.br` pode bloquear downloads automatizados. A função
`obter_dados_tse(ano, uf)` (em `R/01_aquisicao.R`) trata isso assim:

1. Verifica primeiro se o arquivo já existe em
   `data-raw/downloads/{ano}/votacao_candidato_munzona/`.
2. Se não existir, **não tenta baixar automaticamente** (dado o bloqueio
   atual do TSE) — aborta com uma mensagem indicando a URL do portal e o
   caminho exato onde salvar o arquivo, e grava um
   `README_DOWNLOAD_MANUAL.md` na pasta de destino.
3. Baixe o ZIP manualmente pelo navegador em dadosabertos.tse.jus.br
   (Resultados → votação por candidato, município e zona) e salve em
   `data-raw/downloads/{ano}/votacao_candidato_munzona/`. O restante do
   pipeline não diferencia arquivo baixado manualmente de automático — um
   fallback de download automático via `httr2` pode ser adicionado depois
   do defeso eleitoral, sem mudar essa interface.

## Layout real do dataset TSE "votação candidato/município/zona" (2022)

Descoberto ao validar a Fase 1 com os dados de 2022 — vale checar se ainda é
válido ao trocar para 2026:

- O TSE distribui **um único ZIP nacional** por ano (não um ZIP por UF).
  Dentro dele, um CSV por UF: `votacao_candidato_munzona_{ano}_{UF}.csv`
  (ex.: `..._PE.csv`) — cobre só as eleições de **abrangência estadual**
  (Governador, Senador, Deputado Federal, Deputado Estadual).
- **Presidente é um arquivo separado, `..._BR.csv`**, pseudo-UF `"BR"`
  (eleição de abrangência federal) — nacional, todos os municípios do
  Brasil de uma vez, ~38MB. Não precisa de loop por UF para presidente.
  `obter_dados_tse(ano, "BR")` já funciona, sem mudança de código, porque
  `"BR"` é só mais um valor aceito onde a função espera uma UF.
- Existe também `..._BRASIL.csv` (~4,3GB): é só a concatenação de todos os
  CSVs estaduais por UF. **Não usar** — é redundante e pesado demais pra
  ler de uma vez; a agregação nacional (Fase 7) deve ser feita por loop
  sobre os arquivos por UF, não lendo esse consolidado.
- O universo de "municípios" no arquivo `_BR.csv` inclui códigos especiais
  de zonas eleitorais no exterior (votação de brasileiros fora do país) —
  aparecem como município/UF extras que não existem no `geobr`. A Fase 2
  (limpeza) precisa filtrar essas linhas antes do join geográfico.
- `read.csv2()` com `fileEncoding = "latin1"` só funciona lendo de um
  arquivo em disco — passar `encoding`/`fileEncoding` para uma conexão
  `unz()` direto do ZIP dá erro de "string multibyte inválida". Por isso
  `ler_votacao_munzona()` extrai o CSV do UF pedido para `data/interim/`
  (cache, reaproveitado se já existir) antes de ler.
- Validado contra resultado oficial conhecido: 2º turno Governador PE 2022
  (Raquel Lyra 58,70% vs. Marília Arraes 41,30%, 185 municípios) e 2º turno
  Presidente 2022 nacional (Lula 50,90% vs. Bolsonaro 49,10%).

## Nota de ambiente: pin de `httr2@1.2.3`

Encontrado ao instalar `geobr` (set/2026): a versão mais recente do `httr2`
no CRAN exige `rlang >= 1.3.0`, mas o **binário Windows** do `rlang 1.3.0`
para R 4.4 ainda não foi publicado (só a versão fonte existe). Tentar
instalar essa versão baixa silenciosamente um zip com conteúdo de
`rlang 1.2.0` — parece ter funcionado, mas quebra o carregamento de
qualquer pacote que exija a versão nova de verdade. Corrigido fixando
`httr2@1.2.3` (só exige `rlang >= 1.1.0`, compatível com o binário real
disponível), instalado a partir do tarball fonte
(`install.packages(path, type = "source", dependencies = FALSE)` —
`httr2` é R puro, não precisa de Rtools). Se `renv::install("httr2")` ou
`renv::restore()` tentar atualizar para uma versão mais nova, checar
primeiro se o binário do `rlang` exigido já foi publicado para Windows
(`https://cloud.r-project.org/bin/windows/contrib/4.4/PACKAGES`) antes de
aceitar o upgrade.

Mesmo padrão apareceu de novo com `duckdb`/`duckspatial` (dependências
transitivas do `geobr`, não usadas diretamente pelo pipeline): metadado diz
que existe `duckdb 1.5.5`, mas o binário Windows real ainda é `1.5.2`,
então `renv::snapshot()` recusa por validação de versão. Como não usamos
`duckdb` diretamente, contornado com
`renv::snapshot(prompt = FALSE, force = TRUE)`. Se isso passar a dar
problema de verdade (algo que use `duckdb` quebrando), o fix é o mesmo:
checar se o binário real já foi publicado antes de forçar.

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

- Fase 0 (bootstrap) completa: estrutura de pastas, `renv` validado
  (incluindo `V8`/`rmapshaper` via binário no Windows).
- Fase 1 (aquisição + leitura, piloto PE) completa: `R/01_aquisicao.R` e
  `R/02_leitura.R` implementados e validados contra resultado oficial
  conhecido (ver seção "Layout real do dataset TSE" acima).
- Fase 2 (limpeza — `R/03_limpeza.R`) completa: agrega por município/turno,
  soma zonas, calcula `pct_validos`. Validado (10 testes): % soma 100 por
  município, só cargos relevantes (Presidente/Governador/Senador), mesmos
  números da Fase 1.
- Fase 3 (crosswalk/join geográfico) completa:
  - `R/04_crosswalk.R` — TSE→IBGE via `data-raw/ref/linkador_bases.xlsx`
    (fornecido pelo usuário), join por `CD_MUNICIPIO` + `SG_UF`. Validado:
    185/185 municípios de PE casados, 0 sem correspondência.
  - `R/05_geo_join.R` — geometria via `geobr` + de-para
    município→meso/microrregião por join espacial (sem tabela externa).
    Validado: 185/185 municípios de PE com meso/microrregião atribuída,
    Recife → "Metropolitana de Recife", Fernando de Noronha corretamente
    isolado como microrregião própria.
- Fase 4 (cores — `R/06_cores.R`) completa: tabela de referência
  (`data-raw/ref/partidos_cores.csv`, ~25 partidos conhecidos — primeira
  versão, cores aproximadas, ajustar manualmente se necessário) + fallback
  determinístico por hash da sigla (HSL com saturação/luminosidade fixas)
  para qualquer partido não catalogado. Override opcional por candidato em
  `data-raw/ref/candidatos_cores_override.csv` (vazio por padrão).
  Validado: os 10 candidatos ao governo de PE no 1º turno de 2022 saem com
  10 cores distintas (5 de partidos catalogados, 5 geradas por hash).
- Fase 5 (vencedores — `R/07_vencedores.R`) completa: `agregar_por_unidade()`
  soma votos na unidade pedida (município/microrregião/mesorregião/UF) e
  recalcula `pct_validos` em relação ao total da unidade;
  `calcular_vencedor()` pega o maior votado por unidade/cargo/turno.
  Validado nas 4 unidades para governador PE 2022 2º turno: resultado por
  UF bate exatamente com o número nacional já validado na Fase 1 (Raquel
  Lyra 3.113.415 votos, 58,70%); `pct_validos` soma 100 em toda unidade.
- Fase 6 (LISA — `R/08_lisa.R`) completa, só município:
  `construir_vizinhanca()` (`spdep::poly2nb(queen=TRUE)`, com município-ilha
  sem vizinho por contiguidade — ex. Fernando de Noronha — recebendo o
  vizinho mais próximo por distância, nos dois sentidos);
  `calcular_lisa()` (`spdep::localmoran_perm()`, quadrante HH/LL/HL/LH via
  `Pr(folded) Sim`, "Não significante" quando p ≥ alpha). Validado com %
  de votos da Raquel Lyra (governador PE 2022, 2º turno): clusters HH
  concentrados no Agreste (Caruaru 83,4%) e LL no Sertão do São Francisco
  (Belém do São Francisco 28,9%) — geograficamente coerente; Fernando de
  Noronha processado sem erro.
- Fase 7 (exportação — `R/09_exportar.R`) completa: `exportar_topojson()`
  (`rmapshaper::ms_simplify` + `geojsonio::topojson_write`, geometria de
  PE caiu de 18.167 para 5.059 vértices com `keep=0.15`, arquivo de
  148KB); `montar_resultado_unidade()` monta vencedores + candidatos
  (valores por unidade + LISA quando é município) — a cor é calculada
  *na hora da exportação*, não antes da agregação (`agregar_por_unidade()`
  não preserva colunas fora do `group_by`, então carregar a cor cedo e
  tentar arrastá-la pela agregação some silenciosamente sem erro — bug já
  encontrado e corrigido). `pipeline/run_pipeline.R` orquestra tudo
  (`processar_uf(ano, uf)`) e já rodou de ponta a ponta para PE
  (Governador + Senador, 1º/2º turno, 4 unidades): gerou
  `output/geo/{municipios,mesorregioes,microrregioes}_PE.topojson` e 12
  arquivos em `output/results/2022/`, todos com cor preenchida em todo
  candidato/vencedor e LISA presente em nível de município.
- Front-end estático (`frontend/`) implementado: Leaflet + `topojson-client`
  via CDN, sem build step. Seletores Cargo/Turno/Unidade/Modo/Candidato
  populados dinamicamente a partir de `output/index.json` (nada
  hardcoded). Modo "Candidato isolado (contínuo)" interpola branco → cor
  do candidato pelo `%`; modo LISA usa paleta fixa HH/LL/HL/LH/Não
  significante; ambos só ficam disponíveis pra unidade "município" onde
  faz sentido (LISA) ou sempre (contínuo). Unidade "UF" fica de fora do
  seletor por enquanto — não exportamos um TopoJSON de contorno estadual
  ainda (só relevante em escala nacional, com as 27 UFs desenhadas juntas).
  `BASE = ".."` em `frontend/js/dados.js` assume `frontend/` e `output/`
  como pastas irmãs — ajustar se a estrutura de hospedagem final mudar.
  Dois bugs encontrados e corrigidos ao validar a cadeia completa: (1) a
  cor sumia silenciosamente no JSON exportado (mesma causa raiz do bug já
  descrito acima); (2) `arquivo_geo` da unidade "uf" virava a string
  literal `"NA"` em vez de `null` no JSON — `file.path()` converte `NA`
  em `"NA"` ao concatenar com `paste()`, então o problema nunca chegava
  no `jsonlite`, já nascia errado no `file.path()`.
  **Verificação feita**: servidor estático local (`python -m http.server`)
  confirmou que todo caminho referenciado por `index.json` e pelo HTML
  resolve (200) sem 404; os 5 vencedores por mesorregião (Governador PE
  2022, 2º turno) foram conferidos um a um contra o resultado já validado
  na Fase 5 — todos batem, com cor e `%` corretos. **Não verificado**:
  render visual real num navegador (sem ferramenta de automação de
  browser disponível neste ambiente) — abrir
  `http://localhost:PORTA/frontend/index.html` (servindo a raiz do
  projeto) e conferir visualmente os 3 modos ainda é um passo pendente
  antes de considerar essa fase encerrada.
- Ajustes pedidos pelo usuário após a 1ª validação visual, todos
  aplicados:
  - **Vencedor em duas tonalidades por margem** (como no protótipo
    antigo): `calcular_vencedor()` (`R/07_vencedores.R`) agora calcula
    `margem` (`%` do 1º - `%` do 2º colocado na unidade) e `intensidade`
    ("alta"/"baixa", corte pela mediana das margens *dentro das unidades
    que aquele candidato venceu* — mesmo critério do protótipo). Isso
    generaliza igual pras 4 unidades, mas faz cada vez menos sentido
    estatístico quanto menos unidades um candidato ganha — degenerado com
    1 UF só (sempre cai em "baixa"), só é realmente útil em escala
    nacional pra unidade UF. `frontend/js/cores.js` ganhou
    `escurecer()`; o front-end escurece a cor do vencedor pra "alta" e
    clareia pra "baixa" (`estiloVencedor()` em `mapa.js`), com 2 linhas
    por candidato na legenda.
  - **Tema claro/escuro**, escuro por padrão: `frontend/js/tema.js`
    alterna `body[data-tema]`, troca o tile layer do Leaflet (ver `TILES`
    em `mapa.js`) e lembra a preferência em `localStorage`. Variáveis de
    cor em `:root`/`body[data-tema="claro"]` no CSS. Tile do tema escuro
    trocado depois de um ajuste — ver bullet abaixo.
  - **Painel de filtros flutuante**: `#controles` virou `position:
    absolute` sobre o mapa (que agora ocupa a tela inteira), com
    `L.DomEvent.disableClickPropagation`/`disableScrollPropagation` pra
    interagir com os seletores não mexer no mapa por baixo.
  - **Contorno preto ao clicar removido; popup no lugar de tooltip**:
    Leaflet dá foco (outline) ao polígono clicado por padrão — CSS
    `.leaflet-interactive:focus { outline: none; }` tira isso.
    `layer.bindTooltip()` (hover) virou `layer.bindPopup()` (clique).
- Ajustes pedidos pelo usuário na 2ª validação visual, todos aplicados:
  - **Tile do tema escuro trocado de CartoDB Dark Matter para Esri World
    Dark Gray Base**: o CartoDB (`basemaps.cartocdn.com`) passou a exigir
    API key (cadastro gratuito na CARTO) — sem chave, as tiles hoje só
    devolvem um aviso "API KEY REQUIRED" em vez do mapa (confirmado via
    `curl` direto na URL). Trocado em `TILES.escuro` (`frontend/js/mapa.js`)
    por `services.arcgisonline.com/.../Canvas/World_Dark_Gray_Base`, que
    não exige chave nem cadastro. Se precisar trocar de novo no futuro,
    testar a URL crua com `curl` antes de assumir que funciona — o erro
    vem como uma tile válida (200 OK, imagem), não como erro HTTP, então
    só aparece testando visualmente.
  - **Nome de candidato normalizado**: o TSE manda `NM_URNA_CANDIDATO` em
    CAIXA ALTA (ex. "RAQUEL LYRA"). `normalizar_nome_candidato()`, nova em
    `R/03_limpeza.R`, deixa só a 1ª letra de cada palavra maiúscula
    (conectivos "de"/"da"/"do"/"dos"/"das"/"e" ficam minúsculos, exceto
    se forem a 1ª palavra), aplicada dentro de `limpar_votacao()` — assim
    o nome já sai normalizado de um único lugar e propaga para
    vencedores/legenda/popup sem precisar mexer no front-end. Pipeline
    reexecutado para PE após a mudança; testes que comparavam contra o
    literal `"RAQUEL LYRA"` (`test-vencedores.R`, `test-lisa.R`)
    atualizados para `"Raquel Lyra"` — `test-leitura.R` continua
    comparando a versão crua (lê direto de `ler_votacao_munzona()`, antes
    da normalização, de propósito).
  - **Botão de tema em texto**: trocado o emoji 🌙/☀️ por texto
    "Escuro"/"Claro" (`tema.js` + estado inicial no HTML), botão passou de
    quadrado fixo pra largura automática com padding (CSS).
  - **Legenda do modo vencedor sem duplicar linha por candidato**: antes
    mostrava 2 linhas por candidato (uma por intensidade); agora mostra 1
    linha só, sempre no tom mais escuro (`Cores.escurecer(cor, 0.25)`), e
    uma nota fixa abaixo da legenda explicando que tom mais escuro =
    margem maior e mais claro = margem menor (`seletores.js` +
    `.legenda-nota` no CSS).
  - **Linhas dos polígonos mais finas**: `weight` de todos os estilos em
    `mapa.js` (vencedor/isolado/LISA) baixado de `1` para `0.4`.
- Próximo passo: usuário validar visualmente no navegador de novo;
  depois disso, escala nacional (27 UFs) — ver
  `C:\Users\felip\.claude\plans\proud-growing-metcalfe.md` para o plano de
  fases completo.
