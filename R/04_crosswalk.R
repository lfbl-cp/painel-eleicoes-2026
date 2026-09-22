# Crosswalk entre o código de município do TSE (CD_MUNICIPIO, só único
# dentro da própria UF) e o código IBGE de 7 dígitos, usando o arquivo
# fornecido pelo usuário (data-raw/ref/linkador_bases.xlsx) em vez de join
# por nome (frágil a acento/grafia, como no protótipo antigo).

#' Carrega o crosswalk TSE -> IBGE já fornecido.
carregar_crosswalk_tse_ibge <- function(caminho = "data-raw/ref/linkador_bases.xlsx") {
  bruto <- readxl::read_excel(caminho, sheet = "Sheet1")

  dplyr::select(
    bruto,
    CD_MUNICIPIO = "id_TSE",
    SG_UF = "estado_abrev",
    code_muni = "id_munic_7",
    name_muni = "municipio"
  )
}

#' Junta os dados limpos (de `limpar_votacao()`) ao código IBGE do
#' município, via `CD_MUNICIPIO` + `SG_UF` (o código do TSE só é único
#' dentro da UF, por isso o join usa as duas colunas).
#'
#' Linhas sem correspondência (município do exterior, ou um TSE/UF fora do
#' crosswalk) ficam com `code_muni = NA` e são reportadas via aviso, nunca
#' descartadas silenciosamente — quem chama decide o que fazer com elas.
juntar_ibge <- function(dados_limpos, crosswalk) {
  juntado <- dplyr::left_join(dados_limpos, crosswalk, by = c("CD_MUNICIPIO", "SG_UF"))

  nao_casados <- dplyr::distinct(
    juntado[is.na(juntado$code_muni), c("SG_UF", "CD_MUNICIPIO", "NM_MUNICIPIO")]
  )

  if (nrow(nao_casados) > 0) {
    cli::cli_warn(c(
      "{nrow(nao_casados)} combinação(ões) UF/CD_MUNICIPIO sem code_muni no crosswalk.",
      "i" = "Provavelmente voto no exterior (arquivo BR) ou município fora do linkador_bases.xlsx."
    ))
  }

  juntado
}
