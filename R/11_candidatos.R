# Candidatos: dados do card (consulta_cand do TSE), redes sociais, fotos
# oficiais e o ranking dos mais votados de cada escopo (Brasil ou UF), por
# cargo/turno -- o que o painel flutuante da direita do front-end mostra.
# Mesmo modelo do Dashboard-legislativo-2026 (R/03_candidatos.R e
# R/07_fotos.R), restrito a Presidente/Governador/Senador.
#
# Arquivos esperados (todos gitignored, em data-raw/downloads/{ano}/):
#   votacao_candidato_munzona/votacao_candidato_munzona_{ano}.zip (já usado
#     pelo resto do pipeline -- aqui só pros votos/situação por turno)
#   consulta_cand/consulta_cand_{ano}.zip
#   consulta_cand/rede_social_candidato_{ano}.zip (opcional)
#   fotos/foto_cand{ano}_{UF}_div.zip, inclusive UF "BR" (Presidente)

# CD_CARGO do TSE -> DS_CARGO usado no resto do pipeline (o consulta_cand
# traz DS_CARGO em CAIXA ALTA, a votação não).
CARGOS_CD <- c("1" = "Presidente", "3" = "Governador", "5" = "Senador")

# Só as colunas usadas. O consulta_cand traz CPF, e-mail e título de eleitor
# -- ficam de fora já na leitura, nunca entram no pipeline.
COLUNAS_CONSULTA_CAND <- c(
  "SG_UF", "CD_CARGO", "SQ_CANDIDATO", "NR_CANDIDATO", "NM_CANDIDATO", "NM_URNA_CANDIDATO",
  "SG_PARTIDO", "NM_COLIGACAO", "DT_NASCIMENTO", "DS_GENERO", "DS_GRAU_INSTRUCAO", "DS_OCUPACAO"
)
COLUNAS_VOTOS <- c("NR_TURNO", "SG_UF", "DS_CARGO", "SQ_CANDIDATO", "QT_VOTOS_NOMINAIS_VALIDOS", "DS_SIT_TOT_TURNO")

# Data do 1º turno, pra idade do candidato na eleição.
DATAS_ELEICAO <- c("2022" = "2022-10-02", "2026" = "2026-10-04")

dir_downloads_ano <- function(ano, sub, base_dir = "data-raw/downloads") file.path(base_dir, ano, sub)

#' Lê CSVs (latin1, `;`) de dentro de um ZIP do TSE, extraindo só os
#' membros pedidos pra `dir_cache` (cache, reaproveitado). `padrao` filtra os
#' membros por regex sobre o nome.
ler_csvs_zip <- function(zip, padrao, colunas, dir_cache) {
  membros <- grep(padrao, utils::unzip(zip, list = TRUE)$Name, value = TRUE)
  dir.create(dir_cache, recursive = TRUE, showWarnings = FALSE)
  faltando <- membros[!file.exists(file.path(dir_cache, membros))]
  if (length(faltando) > 0) utils::unzip(zip, files = faltando, exdir = dir_cache)
  data.table::rbindlist(lapply(file.path(dir_cache, membros), function(f) {
    data.table::fread(f, sep = ";", encoding = "Latin-1", select = colunas,
                      colClasses = list(character = "SQ_CANDIDATO"), na.strings = VALORES_AUSENTES_TSE)
  }), use.names = TRUE)
}

#' Votos e situação (DS_SIT_TOT_TURNO) por candidato, turno e UF do eleitor,
#' dos 3 cargos do painel. Presidente vem do arquivo "BR" (SG_UF = UF do
#' município; "ZZ" = exterior, que entra no total nacional mas em nenhuma UF).
ler_votos_candidatos <- function(ano, dir_cache = file.path("data/interim", ano)) {
  zip <- obter_zip_tse(ano)
  padrao <- sprintf("^votacao_candidato_munzona_%d_[A-Z]{2}\\.csv$", ano)
  x <- ler_csvs_zip(zip, padrao, COLUNAS_VOTOS, dir_cache)
  x <- x[x$DS_CARGO %in% CARGOS_RELEVANTES]
  x[, list(votos = sum(QT_VOTOS_NOMINAIS_VALIDOS, na.rm = TRUE), situacao = DS_SIT_TOT_TURNO[1]),
    by = c("NR_TURNO", "SG_UF", "DS_CARGO", "SQ_CANDIDATO")]
}

ler_consulta_cand <- function(ano, dir_cache = file.path("data/interim", ano, "consulta_cand")) {
  zip <- file.path(dir_downloads_ano(ano, "consulta_cand"), sprintf("consulta_cand_%d.zip", ano))
  if (!file.exists(zip)) cli::cli_abort("Não encontrado: {.file {zip}} (baixar de dadosabertos.tse.jus.br).")
  # Um CSV por UF + "_BR" (Presidente); "_BRASIL" é a concatenação, fora.
  x <- ler_csvs_zip(zip, sprintf("^consulta_cand_%d_[A-Z]{2}\\.csv$", ano), COLUNAS_CONSULTA_CAND, dir_cache)
  x <- x[as.character(x$CD_CARGO) %in% names(CARGOS_CD)]
  # Uma linha por candidatura (o TSE repete o candidato no 2º turno).
  unique(x, by = "SQ_CANDIDATO")
}

# --- redes sociais (mesma limpeza do Dashboard-legislativo-2026) ---------------
HOSTS_REDES <- c("instagram.com", "facebook.com", "fb.com", "tiktok.com", "twitter.com",
                 "x.com", "youtube.com", "threads.com", "threads.net", "kwai.com",
                 "linkedin.com", "linktr.ee")
MAX_REDES <- 6

#' Normaliza a URL declarada (o TSE traz URL em CAIXA ALTA, sem esquema, com
#' parâmetros de rastreamento). Rede conhecida: minúsculas e sem query.
limpar_url_rede <- function(url) {
  u <- trimws(url)
  u <- ifelse(grepl("^[a-zA-Z][a-zA-Z0-9+.-]*://", u), u, paste0("https://", u))
  partes <- regmatches(u, regexec("^([^:]+)://([^/?#]+)([^?#]*)(.*)$", u))
  vapply(partes, function(p) {
    if (length(p) == 0) return(NA_character_)
    host <- tolower(p[3])
    caminho <- p[4]
    conhecida <- any(host == HOSTS_REDES | endsWith(host, paste0(".", HOSTS_REDES)))
    if (conhecida) return(paste0("https://", host, sub("/+$", "", tolower(caminho))))
    paste0(tolower(p[2]), "://", host, caminho, p[5])
  }, character(1))
}

#' URLs de redes por SQ_CANDIDATO (lista nomeada), até MAX_REDES cada, sem
#' repetir. Lista vazia se o ZIP de redes não existir.
ler_redes <- function(ano, dir_cache = file.path("data/interim", ano, "rede_social")) {
  zip <- file.path(dir_downloads_ano(ano, "consulta_cand"), sprintf("rede_social_candidato_%d.zip", ano))
  if (!file.exists(zip)) return(list())
  x <- ler_csvs_zip(zip, sprintf("^rede_social_candidato_%d_[A-Z]{2}\\.csv$", ano), c("SQ_CANDIDATO", "DS_URL"), dir_cache)
  x$url <- limpar_url_rede(x$DS_URL)
  x <- unique(x[!is.na(x$url), c("SQ_CANDIDATO", "url")])
  lapply(split(x$url, x$SQ_CANDIDATO), function(u) utils::head(u, MAX_REDES))
}

#' Copia as fotos oficiais (F{UF}{SQ}_div.jpg nos ZIPs por UF) dos candidatos
#' pedidos para `dir_saida/{sq}.jpg`. Devolve os SQs que têm foto.
extrair_fotos <- function(ano, sq_por_uf, dir_saida) {
  dir.create(dir_saida, recursive = TRUE, showWarnings = FALSE)
  for (uf in names(sq_por_uf)) {
    sq <- sq_por_uf[[uf]]
    destinos <- file.path(dir_saida, paste0(sq, ".jpg"))
    if (all(file.exists(destinos))) next
    zip <- file.path(dir_downloads_ano(ano, "fotos"), sprintf("foto_cand%d_%s_div.zip", ano, uf))
    if (!file.exists(zip)) {
      cli::cli_warn("Sem ZIP de fotos {.file {zip}} -- candidatos de {uf} ficam com as iniciais.")
      next
    }
    lista <- utils::unzip(zip, list = TRUE)$Name
    sq_zip <- sub("^F[A-Z]{2}(\\d+)_div\\.(jpe?g|png)$", "\\1", basename(lista), ignore.case = TRUE)
    alvo <- lista[sq_zip %in% sq[!file.exists(destinos)]]
    if (length(alvo) == 0) next
    tmp <- tempfile("fotos_")
    utils::unzip(zip, files = alvo, exdir = tmp, junkpaths = TRUE)
    file.copy(file.path(tmp, basename(alvo)), file.path(dir_saida, paste0(sq_zip[match(alvo, lista)], ".jpg")), overwrite = TRUE)
    unlink(tmp, recursive = TRUE)
  }
  sub("\\.jpg$", "", list.files(dir_saida, pattern = "\\.jpg$"))
}

#' "ELEITO"/"2º TURNO"/"NÃO ELEITO" -> rótulo do painel. O 2º turno ainda
#' não disputado (ano sem resultado de 2º turno) é "Disputa o 2º turno".
rotular_situacao <- function(ds, tem_segundo_turno) {
  s <- toupper(chartr("ÁÃÉÊÍÓÔÕÚÇ", "AAEEIOOOUC", ds))
  dplyr::case_when(
    grepl("^ELEITO", s) ~ "Eleito",
    grepl("2. TURNO", s) & tem_segundo_turno ~ "Foi ao 2º turno",
    grepl("2. TURNO", s) ~ "Disputa o 2º turno",
    grepl("^NAO ELEITO", s) ~ "Não eleito",
    TRUE ~ NA_character_
  )
}

#' Ranking (todos os candidatos, do mais ao menos votado) por cargo, turno e
#' escopo. Escopo UF: votos do candidato na UF sobre os válidos do cargo na
#' UF (Presidente: só os eleitores daquela UF). Escopo "BR": Presidente =
#' nacional (com o exterior); Governador/Senador = todos os candidatos das 27
#' UFs juntos, cada um com o % sobre os válidos da própria UF (mesmo critério
#' do mosaico nacional).
#'
#' @return lista cargo -> turno -> escopo -> lista de {sq, votos, pct}.
montar_rankings <- function(tab) {
  linhas <- function(d, total) {
    d <- d[order(-d$votos)]
    lapply(seq_len(nrow(d)), function(i) list(sq = d$SQ_CANDIDATO[i], votos = d$votos[i], pct = round(100 * d$votos[i] / total[i], 2)))
  }
  saida <- list()
  for (cargo in intersect(CARGOS_RELEVANTES, unique(tab$DS_CARGO))) {
    for (turno in sort(unique(tab$NR_TURNO[tab$DS_CARGO == cargo]))) {
      v <- tab[tab$DS_CARGO == cargo & tab$NR_TURNO == turno]
      por_uf <- v[v$SG_UF != "ZZ"]
      por_uf[, total := sum(votos), by = "SG_UF"]
      escopos <- list()
      for (uf in sort(unique(por_uf$SG_UF))) {
        d <- por_uf[por_uf$SG_UF == uf]
        escopos[[uf]] <- linhas(d, d$total)
      }
      if (cargo == "Presidente") {
        nac <- v[, list(votos = sum(votos)), by = "SQ_CANDIDATO"]
        escopos[["BR"]] <- linhas(nac, rep(sum(nac$votos), nrow(nac)))
      } else {
        escopos[["BR"]] <- linhas(por_uf, por_uf$total)
      }
      saida[[cargo]][[as.character(turno)]] <- escopos
    }
  }
  saida
}

#' Monta e exporta `output/candidatos/{ano}.json` (cards + rankings) e as
#' fotos em `output/fotos/{ano}/`. Só entram candidatos com voto
#' totalizado nos 3 cargos do painel.
exportar_candidatos <- function(ano, diretorio_saida = "output") {
  cli::cli_inform("Candidatos {ano}: votos, consulta_cand, redes e fotos...")
  votos <- ler_votos_candidatos(ano)
  tem_t2 <- any(votos$NR_TURNO == 2)
  cand <- ler_consulta_cand(ano)
  cand <- cand[cand$SQ_CANDIDATO %in% votos$SQ_CANDIDATO]
  redes <- ler_redes(ano)

  # UF do ZIP de fotos: "BR" pro Presidente, a UF da candidatura pros demais.
  uf_foto <- ifelse(as.character(cand$CD_CARGO) == "1", "BR", cand$SG_UF)
  com_foto <- extrair_fotos(ano, split(cand$SQ_CANDIDATO, uf_foto), file.path(diretorio_saida, "fotos", ano))

  totais <- votos[, list(votos = sum(votos), situacao = situacao[1]), by = c("SQ_CANDIDATO", "NR_TURNO")]
  data_eleicao <- as.Date(DATAS_ELEICAO[[as.character(ano)]])
  dt_nasc <- as.Date(cand$DT_NASCIMENTO, format = "%d/%m/%Y")
  idade <- as.integer(floor(as.numeric(data_eleicao - dt_nasc) / 365.25))
  coligacao <- ifelse(cand$NM_COLIGACAO %in% c("PARTIDO ISOLADO", "FEDERAÇÃO", NA), NA_character_, cand$NM_COLIGACAO)

  candidatos <- lapply(seq_len(nrow(cand)), function(i) {
    sq <- cand$SQ_CANDIDATO[i]
    t <- totais[totais$SQ_CANDIDATO == sq]
    list(
      nome = normalizar_nome_candidato(cand$NM_URNA_CANDIDATO[i]),
      nome_completo = normalizar_nome_candidato(cand$NM_CANDIDATO[i]),
      cargo = CARGOS_CD[[as.character(cand$CD_CARGO[i])]],
      uf = if (as.character(cand$CD_CARGO[i]) == "1") "BR" else cand$SG_UF[i],
      partido = cand$SG_PARTIDO[i],
      numero = cand$NR_CANDIDATO[i],
      idade = idade[i],
      genero = cand$DS_GENERO[i],
      ocupacao = cand$DS_OCUPACAO[i],
      instrucao = cand$DS_GRAU_INSTRUCAO[i],
      coligacao = coligacao[i],
      foto = sq %in% com_foto,
      redes = I(redes[[sq]] %||% character()),
      votos = stats::setNames(as.list(t$votos), as.character(t$NR_TURNO)),
      situacao = stats::setNames(as.list(rotular_situacao(t$situacao, tem_t2)), as.character(t$NR_TURNO))
    )
  })
  names(candidatos) <- cand$SQ_CANDIDATO

  caminho <- file.path(diretorio_saida, "candidatos", sprintf("%d.json", ano))
  exportar_resultado_json(list(ano = ano, candidatos = candidatos, ranking = montar_rankings(votos)), caminho)
  cli::cli_inform("Candidatos {ano}: {length(candidatos)} candidatos, {sum(cand$SQ_CANDIDATO %in% com_foto)} com foto -> {.file {caminho}}.")
  invisible(caminho)
}
