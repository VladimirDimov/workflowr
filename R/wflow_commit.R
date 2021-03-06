#' Commit files
#'
#' \code{wflow_commit} adds and commits files with Git. This is a convenience
#' function to run Git commands from the R console instead of the shell. For
#' most use cases, you should use \code{\link{wflow_publish}} instead, which
#' calls \code{wflow_commit} and then subsequently also builds and commits the
#' website files.
#'
#' Some potential use cases for \code{wflow_commit}:
#'
#' \itemize{
#'
#' \item Commit drafts which you do not yet want to be included in the website
#'
#' \item Commit files which do not directly affect the website (e.g. when you
#' are writing scripts for a data processing pipeline)
#'
#' \item Manually commit files in \code{docs/} (proceed with caution!). This
#' should only be done for content that is not automatically generated from the
#' source files in the analysis directory, e.g. an image file you want to
#' include in one of your pages.
#'
#' }
#'
#' Under the hood, \code{wflow_commit} is a wrapper for \code{\link[git2r]{add}}
#' and \code{\link[git2r]{commit}} from the package \link{git2r}.
#'
#' @param files character (default: NULL). Files to be added and committed with
#'   Git.
#' @param message character (default: NULL). A commit message.
#' @param all logical (default: FALSE). Automatically stage files that have been
#'   modified and deleted. Equivalent to: \code{git commit -a}
#' @param force logical (default: FALSE). Allow adding otherwise ignored files.
#'   Equivalent to: \code{git add -f}
#' @param dry_run logical (default: FALSE). Preview the proposed action but do
#'   not actually add or commit any files.
#' @param project character (default: ".") By default the function assumes the
#'   current working directory is within the project. If this is not true,
#'   you'll need to provide the path to the project directory.
#'
#' @return An object of class \code{wflow_commit}, which is a list with the
#'   following elements:
#'
#' \itemize{
#'
#' \item \bold{files}: The input argument \code{files}.
#'
#' \item \bold{message}: The message describing the commit.
#'
#' \item \bold{all}: The input argument \code{all}.
#'
#' \item \bold{force}: The input argument \code{force}.
#'
#' \item \bold{dry_run}: The input argument \code{dry_run}.
#'
#' \item \bold{commit}: The \code{\link[git2r]{git_commit-class}} object
#' returned by \link{git2r} (only included if \code{dry_run == FALSE}).
#'
#' \item \bold{commit_files}: The relative path(s) to the file(s) included in
#' the commit (only included if \code{dry_run == FALSE}).
#'
#' }
#'
#' @seealso \code{\link{wflow_publish}}
#'
#' @examples
#' \dontrun{
#'
#' # Commit a single file
#' wflow_commit("analysis/file.Rmd", "Add new analysis")
#' # Commit multiple files
#' wflow_commit(c("code/process-data.sh", "output/small-data.txt"),
#'              "Process data set")
#' # Add and commit all tracked files, similar to `git commit -a`
#' wflow_commit(message = "Lots of changes", all = TRUE)
#' }
#'
#' @export
wflow_commit <- function(files = NULL, message = NULL, all = FALSE,
                         force = FALSE, dry_run = FALSE, project = ".") {

  if (!is.null(files)) {
    if (!is.character(files)) {
      stop("files must be NULL or a character vector of filenames")
    } else if (!all(file.exists(files))) {
      stop("Not all files exist. Check the paths to the files")
    }
    # Ensure Windows paths use forward slashes
    files <- convert_windows_paths(files)
    # Change filepaths to relative paths
    files <- relpath_vec(files)
  }

  if (is.null(message)) {
    message <- deparse(sys.call())
    message <- paste(message, collapse = "\n")
  } else if (is.character(message)) {
    message <- wrap(paste(message, collapse = " "))
  } else {
    stop("message must be NULL or a character vector")
  }

  if (!(is.logical(all) && length(all) == 1))
    stop("all must be a one-element logical vector")

  if (!(is.logical(force) && length(force) == 1))
    stop("force must be a one-element logical vector")

  if (!(is.logical(dry_run) && length(dry_run) == 1))
    stop("dry_run must be a one-element logical vector")

  if (is.character(project) && length(project) == 1) {
    # Ensure Windows paths use forward slashes
    project <- convert_windows_paths(project)
    if (dir.exists(project)) {
      project <- normalizePath(project)
    } else {
      stop("project directory does not exist.")
    }
  } else {
    stop("project must be a one-element character vector")
  }

  if (is.null(files) && !all)
    stop("Must specify files to commit, set `all = TRUE`, or both",
         call. = FALSE)

  # Additional checks of files to be committed
  if (!is.null(files)) {
    # Files must be within the Git repository
    if (!all(sapply(files, git2r::in_repository)))
      stop("Not all files are inside the Git repository")
    # Files cannot be larger than 100MB
    sizes <- file.size(files) / 10^6
    if (any(sizes >= 100))
      stop(wrap("All files to be committed must be less than 100 MB (this is
      the max file size able to be pushed to GitHub). Run Git from the
      commandline if you really want to commit these files."))
  }

  wflow_commit_(files = files, message = message, all = all,
                force = force, dry_run = dry_run, project = project)
}

# Internal function that performs add/commit. Called by wflow_commit.
#
# The primary motivation for having a separate internal function that is called
# by the user facing `wflow_commit` is so that `wflow_publish` can bypass the
# input checks in order to run Step 3 to publish the website files. In a dry
# run, some of the files may not yet be built (which would cause an error).
# Also, not every Rmd file will create output figures, but it's easier to just
# attempt to add figures for every file.
wflow_commit_ <- function(files = files, message = message, all = all,
                          force = force, dry_run = dry_run, project = project) {

  # Obtain workflowr status
  s <- wflow_status(project = project)

  # Establish connection to Git repository
  r <- git2r::repository(s$git)

  if (!dry_run) {
    # Add the specified files
    if (!is.null(files)) {
      git2r::add(r, files, force = force)
    }
    if (all) {
      # Temporary fix until git2r::commit can do `git commit -a`
      # https://github.com/ropensci/git2r/pull/283
      tracked <- rownames(s$status)[s$status$tracked]
      git2r::add(r, tracked)
    }
    # Commit
    tryCatch(
      commit <- git2r::commit(r, message = message, all = all),
      error = function(e) {
        if (stringr::str_detect(e$message, "Nothing added to commit")) {
          reason <- "Commit failed because no files were added."
        } else {
          reason <- "Commit failed for unknown reason."
        }
        stop(wrap(reason, " Any untracked files must manually specified even if
                  `all = TRUE`."), call. = FALSE)
      }
    )
  }

  o <- list(files = files, message = message, all = all, force = force,
            dry_run = dry_run)
  class(o) <- "wflow_commit"
  if (!dry_run) {
    commit_files <- obtain_files_in_commit(r, commit)
    commit_files <- paste0(git2r::workdir(r), commit_files)
    o$commit <- commit
    o$commit_files <- relpath_vec(commit_files)
  }

  return(o)
}

#' @export
print.wflow_commit <- function(x, ...) {
  cat("Summary from wflow_commit\n\n")
  if (x$dry_run) {
    cat(wrap("The following would be attempted:"), "\n\n")
  } else {
    cat(wrap("The following was run:"), "\n\n")
  }
  if (!is.null(x$files)) {
    if (x$force) {
      cat("  $ git add -f", x$files, "\n")
    } else {
      cat("  $ git add", x$files, "\n")
    }
  }
  if (x$all) {
    cat("  $ git commit -a -m", deparse(x$message), "\n")
  } else {
    cat("  $ git commit -m", deparse(x$message), "\n")
  }
  if (!x$dry_run) {
    cat(sep = "", "\n",
        wrap("The following file(s) were included in commit ",
             stringr::str_sub(x$commit@sha, start = 1, end = 7)),
        ":\n")
    cat(shorten_site_libs(x$commit_files), sep = "\n")
  }

  return(invisible(x))
}

# When printing the files included in a commit, only list the first subdirectory
# within `site_libs/`.
shorten_site_libs <- function(files) {
  is_site_libs <- stringr::str_detect(files, "site_libs")
  f_split <- stringr::str_split(files, .Platform$file.sep,
                                simplify = TRUE)
  out <- files
  for (i in seq_along(files)) {
    if (is_site_libs[i]) {
      col_site_libs <- which(f_split[i, ] == "site_libs")
      out[i] <- paste(f_split[i, seq(col_site_libs + 1)],
                      collapse = .Platform$file.sep)
      # Add final / so that it is clear it's a directory
      if (dir.exists(out[i])) {
        out[i] <- paste0(out[i], .Platform$file.sep)
      }
    }
  }
  return(unique(out))
}
