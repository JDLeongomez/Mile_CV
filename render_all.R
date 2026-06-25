scholar_id <- "X58RxbIAAAAJ"
cache_file  <- "scholar_cache.rds"

# Dialog helpers: popup in RStudio, readline fallback in plain R
ask_yn <- function(title, message) {
  if (rstudioapi::isAvailable()) {
    isTRUE(rstudioapi::showQuestion(title, message, ok = "Sí", cancel = "No"))
  } else {
    tolower(trimws(readline(paste0(message, " [s/N]: ")))) == "s"
  }
}

ask_value <- function(label) {
  if (rstudioapi::isAvailable()) {
    val <- rstudioapi::showPrompt(title = label, message = label, default = "")
    if (is.null(val)) stop("Cancelado por el usuario.")
    val
  } else {
    readline(paste0("  ", label, ": "))
  }
}

prompt_manual_metrics <- function() {
  message("\nAbre el perfil de Scholar de Milena en el navegador:")
  message("  https://scholar.google.com/citations?user=X58RxbIAAAAJ\n")

  list(
    profile = list(
      h_index     = as.integer(ask_value("Índice h")),
      i10_index   = as.integer(ask_value("Índice i10")),
      total_cites = as.integer(ask_value("Total de citas")),
      pubs_num    = as.integer(ask_value("Número de publicaciones")),
      g_index     = as.integer(ask_value("Índice g")),
      meancit     = as.numeric(ask_value("Media de citas")),
      mediancit   = as.numeric(ask_value("Mediana de citas"))
    ),
    pubs = data.frame(
      title = character(), journal = character(),
      year = integer(), cites = integer(),
      stringsAsFactors = FALSE
    )
  )
}

message("Obteniendo datos de Google Scholar...")
scholar_data <- tryCatch({
  data <- list(
    profile = scholar::get_profile(scholar_id),
    pubs    = scholar::get_publications(scholar_id)
  )
  if (!is.list(data$profile) || is.null(data$profile$h_index) ||
      is.null(data$pubs) || nrow(data$pubs) == 0) {
    stop("Scholar devolvió datos inválidos (posiblemente bloqueado).")
  }
  saveRDS(data, cache_file)
  message("Datos de Scholar guardados en caché.")
  data
}, error = function(e) {
  message("Error al obtener datos de Scholar: ", conditionMessage(e))
  NULL
})

# Scholar falló — siempre ofrecer entrada manual (el caché puede estar desactualizado)
if (is.null(scholar_data)) {
  if (ask_yn(
    title   = "Scholar no disponible",
    message = "No se pudieron obtener datos de Google Scholar.\n¿Deseas ingresar las métricas manualmente?"
  )) {
    scholar_data <- prompt_manual_metrics()
    saveRDS(scholar_data, cache_file)
    message("Caché guardado con valores ingresados manualmente.")
  } else if (file.exists(cache_file)) {
    message("Cargando datos desde el caché existente.")
    scholar_data <- readRDS(cache_file)
  } else {
    message("Continuando sin datos de Scholar — las métricas mostrarán NA.")
  }
}

# Signal to each Rmd that Scholar data is already resolved for this session
options(mva_scholar_cache_only = TRUE)

cv_dirs <- list.files(".", pattern = "^CV_", include.dirs = TRUE)

for (dir in cv_dirs) {
  for (file in list.files(dir, pattern = "\\.Rmd$")) {
    message("\nRenderizando: ", dir, "/", file)
    withr::with_dir(dir, rmarkdown::render(file))
  }
}

options(mva_scholar_cache_only = FALSE)
message("\n¡Listo!")
