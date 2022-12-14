`%||%` <- function(x, y) {
    if (is.null(x)) y else x
}

has_names <- function(x) {
    nms <- names(x)
    if (is.null(nms)) {
        return(rep(FALSE, length(x)))
    }
    !is.na(nms) & nms != ""
}

#' @importFrom rlang zap
#' @export
rlang::zap

#' Report if an argument is a specific class
#' @keywords internal
#' @noRd
assert_class <- function(x, is_class, class, null_ok = FALSE, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
    message <- "{.cls {class}} object"
    if (null_ok) {
        message <- paste(message, "or {.code NULL}", sep = " ")
    }
    message <- sprintf("{.arg {arg}} must be a %s", message)
    if (is.null(x)) {
        if (!null_ok) {
            cli::cli_abort(c(message,
                "x" = "You've supplied a {.code NULL}"
            ), call = call)
        }
    } else if (!is_class(x)) {
        cli::cli_abort(c(message,
            "x" = "You've supplied a {.cls {class(x)}} object"
        ), call = call)
    }
}

#' Report if an argument has specific length
#' @keywords internal
#' @noRd
assert_length <- function(x, length, null_ok = FALSE, arg = rlang::caller_arg(x), call = rlang::caller_env()) {
    length <- as.integer(length)
    if (identical(length, 1L)) {
        message <- "{.field scalar} object"
    } else {
        message <- "length {.val {length}} object"
    }
    if (null_ok) {
        message <- paste(message, "or {.code NULL}", sep = " ")
    }
    message <- sprintf("{.arg {arg}} must be a %s", message)
    if (is.null(x)) {
        if (!null_ok) {
            cli::cli_abort(c(message,
                "x" = "You've supplied a {.code NULL}"
            ), call = call)
        }
    } else if (!identical(length(x), length)) {
        cli::cli_abort(c(message,
            "x" = "You've supplied a length {.val {length(x)}} object"
        ), call = call)
    }
}

#' Implement similar purrr::imap function
#' @note this function won't keep the names of .x in the final result
#' @keywords internal
#' @noRd
imap <- function(.x, .f, ...) {
    .mapply(
        rlang::as_function(.f),
        dots = list(.x, names(.x) %||% as.character(seq_along(.x))),
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
    if (length(missing_names) > 0L) {
        replace <- replace[!old_names %in% missing_names]
        old_names <- names(replace)
    }
    names(x)[match(old_names, current_names)] <- as.vector(replace)
    x
}

# `NULL` passed to ... will also be kept
modify_list <- function(x, ..., restrict = NULL) {
    dots_list <- rlang::list2(...)
    dots_has_names <- has_names(dots_list)
    if (!all(dots_has_names)) {
        cli::cli_warn(c(
            "All items should be named, will only use the named items.",
            "!" = "A total of {.val {sum(!dots_has_names)}} item{?s} will be omitted"
        ))
        dots_list <- dots_list[dots_has_names]
    }
    if (is.null(restrict)) {
        restrict <- names(dots_list)
    } else {
        restrict <- intersect(restrict, names(dots_list))
    }
    for (name in names(dots_list)) {
        value <- dots_list[[name]]
        if (rlang::is_zap(value)) {
            x[[name]] <- NULL
        } else {
            x[name] <- list(value)
        }
    }
    x
}

# call object utils ----------------------------------------
call_standardise <- function(call, env = rlang::caller_env()) {
    expr <- rlang::get_expr(call)
    env <- rlang::get_env(call, env)
    fn <- rlang::eval_bare(rlang::node_car(expr), env)
    if (rlang::is_primitive(fn)) {
        call
    } else {
        matched <- rlang::call_match(expr, fn, defaults = TRUE)
        rlang::set_expr(call, matched)
    }
}

# find_expr_deps <- function(expr) {
#     # substitute "~" with "base::identity"
#     expr <- rlang::call2(rlang::expr(substitute), expr,
#         env = rlang::expr(list(`~` = base::identity)),
#         .ns = "base"
#     )
#     expr <- rlang::eval_bare(expr, env = rlang::base_env())
#     codetools::findGlobals(rlang::new_function(args = NULL, body = expr))
# }

change_expr <- function(expr, from, to) {
    switch(expr_type(expr),

        # special cases
        # for missing argument in pairlist
        missing = rlang::missing_arg(),

        # seems like this will always live in the end of anonymous function call
        # we just return as it is
        integer = expr,

        # Base cases
        constant = ,
        symbol = if (identical(expr, from)) to else expr,

        # Recursive cases
        call = list_to_call(lapply(expr, change_expr, from = from, to = to)),
        pairlist = rlang::pairlist2(
            !!!lapply(expr, change_expr, from = from, to = to)
        ),
        cli::cli_abort("Don't know how to handle type {.cls {expr_type(expr)}}")
    )
}

list_to_call <- function(x) {
    rlang::call2(x[[1L]], !!!x[-1L])
}

expr_type <- function(x) {
    if (rlang::is_missing(x)) {
        "missing"
    } else if (rlang::is_syntactic_literal(x)) {
        "constant"
    } else if (is.symbol(x)) {
        "symbol"
    } else if (is.call(x)) {
        "call"
    } else if (is.pairlist(x)) {
        "pairlist"
    } else {
        typeof(x)
    }
}

# cli output helper
cli_list <- function(label, items, sep = ": ", add_num = TRUE) {
    items <- cli::cli_vec(items, list("vec-trunc" = 3L))
    message <- "{.field {label}}{sep}{.val {items}}"
    if (add_num) {
        message <- paste(message, "({length(items)} item{?s})", sep = " ")
    }
    cli::cli_li(message)
}
