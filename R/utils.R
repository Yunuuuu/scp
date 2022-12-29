`%||%` <- function(x, y) {
    if (is.null(x)) y else x
}

list_has_element_names <- function(x) {
    if (all(has_names(x))) TRUE else FALSE
}

has_names <- function(x) {
    nms <- names(x)
    if (is.null(nms)) {
        return(rep(FALSE, length(x)))
    }
    !is.na(nms) & nms != ""
}

#' implement similar purrr::imap function 
#' @note this function won't keep the names of .x in the final result
#' @keywords internal
#' @noRd 
imap <- function(.x, .f, ...) {
    .mapply(
        rlang::as_function(.f),
        dots = list(.x, names(.x)), 
        MoreArgs = list(...)
    )
}

#' Rename elements in a list, data.frame or vector
#'
#' This is akin to `dplyr::rename` and `plyr::rename`. It renames elements given
#' as names in the `replace` vector to the values in the `replace` vector
#' without touching elements not referenced.
#'
#' @param x A data.frame or a named vector or list
#' @param replace A named character vector. The names identifies the elements in
#' `x` that should be renamed and the values gives the new names.
#'
#' @return `x`, with new names according to `replace`
#'
#' @keywords internal
#' @noRd
rename <- function(x, replace) {
    current_names <- names(x)
    old_names <- names(replace)
    missing_names <- setdiff(old_names, current_names)
    if (length(missing_names) > 0) {
        replace <- replace[!old_names %in% missing_names]
        old_names <- names(replace)
    }
    names(x)[match(old_names, current_names)] <- as.vector(replace)
    x
}