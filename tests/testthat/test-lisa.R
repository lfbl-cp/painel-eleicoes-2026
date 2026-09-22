source(testthat::test_path("..", "..", "R", "01_aquisicao.R"))
source(testthat::test_path("..", "..", "R", "02_leitura.R"))
source(testthat::test_path("..", "..", "R", "03_limpeza.R"))
source(testthat::test_path("..", "..", "R", "04_crosswalk.R"))
source(testthat::test_path("..", "..", "R", "05_geo_join.R"))
source(testthat::test_path("..", "..", "R", "08_lisa.R"))

dir_downloads <- testthat::test_path("..", "..", "data-raw", "downloads")
dir_interim <- testthat::test_path("..", "..", "data", "interim")
zip_2022 <- file.path(dir_downloads, "2022", "votacao_candidato_munzona", "votacao_candidato_munzona_2022.zip")
linkador <- testthat::test_path("..", "..", "data-raw", "ref", "linkador_bases.xlsx")

testthat::test_that("construir_vizinhanca lida com município-ilha (Fernando de Noronha)", {
  testthat::skip_if_offline()

  municipios_pe <- obter_municipios_sf("PE")
  nb <- spdep::poly2nb(municipios_pe, queen = TRUE)
  testthat::expect_true(any(spdep::card(nb) == 0))

  listw <- construir_vizinhanca(municipios_pe)
  nb_corrigido <- listw$neighbours
  testthat::expect_true(all(spdep::card(nb_corrigido) > 0))
})

testthat::test_that("calcular_lisa reproduz clusters espacialmente plausíveis (Raquel Lyra, PE 2022 2o turno)", {
  testthat::skip_if_not(file.exists(zip_2022), "ZIP de 2022 não encontrado")
  testthat::skip_if_not(file.exists(linkador), "linkador_bases.xlsx não encontrado")
  testthat::skip_if_offline()

  set.seed(42)

  info <- obter_dados_tse(2022, "PE", base_dir = dir_downloads)
  dados <- ler_votacao_munzona(info$zip, info$membro, dir_cache = dir_interim)
  limpo <- limpar_votacao(dados)
  juntado <- juntar_ibge(limpo, carregar_crosswalk_tse_ibge(linkador))

  gov2_raquel <- juntado[
    juntado$DS_CARGO == "Governador" & juntado$NR_TURNO == 2 &
      juntado$NM_URNA_CANDIDATO == "RAQUEL LYRA",
  ]

  municipios_pe <- obter_municipios_sf("PE")
  ordem <- match(municipios_pe$code_muni, gov2_raquel$code_muni)
  testthat::expect_false(anyNA(ordem))

  pct_raquel <- gov2_raquel$pct_validos[ordem]
  listw <- construir_vizinhanca(municipios_pe)
  lisa <- calcular_lisa(pct_raquel, listw, nsim = 499)

  testthat::expect_equal(nrow(lisa), 185)
  testthat::expect_true(all(lisa$cluster %in% c("HH", "LL", "HL", "LH", "Não significante")))

  # Caruaru: alta votação (Agreste), esperado HH
  idx_caruaru <- which(municipios_pe$name_muni == "Caruaru")
  testthat::expect_equal(lisa$cluster[idx_caruaru], "HH")

  # Belém do São Francisco: baixa votação (Sertão do São Francisco), esperado LL
  idx_belem_sf <- which(municipios_pe$name_muni == "Belém do São Francisco")
  testthat::expect_equal(lisa$cluster[idx_belem_sf], "LL")
})
