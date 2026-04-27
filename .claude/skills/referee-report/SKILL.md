---
name: referee-report
description: Read paper PDF, produce Markdown referee report + Beamer critique slides
argument-hint: "[path/to/paper.pdf] [full|mini]"
allowed-tools: ["Read", "Grep", "Glob", "Write", "Edit", "Bash", "Agent"]
---

# Referee Report Workflow

Produce a structured referee report and Beamer critique slide deck for a given paper PDF.

**Input:** `$ARGUMENTS` — e.g., `Papers/Braghieri_etal_2022_DiD.pdf full` or `Papers/Smith2023.pdf mini`

---

## Step 1: Parse Arguments

Extract from `$ARGUMENTS`:
- **PDF path** — path to the paper (check `Papers/` if no directory given)
- **Mode** — `full` (default) or `mini`

If the PDF path is ambiguous, Glob for `Papers/*.pdf` and match the closest name.

---

## Step 2: Read the Paper

Use the Read tool to read the PDF. For papers > 20 pages, read in chunks (pages 1-10, 11-20, etc.) until the full paper is consumed. Take notes on:

- Research question and motivation
- Identification strategy (natural experiment? RD? DiD? IV? Survey?)
- Data sources, sample, key variables, time period
- Estimation approach and specification
- Main results (quantitative)
- Robustness checks reported
- Contribution claim

---

## Step 3: Produce the Critique

After reading the full paper, apply the critique dimensions based on mode:

### Full Mode — 8 Dimensions

1. **Research Question Clarity** — Is the question clearly stated? Motivated well? Novel?
2. **Identification Strategy** — Is the causal claim credible? What are the key identifying assumptions? Are there threats (omitted variables, selection, reverse causality)?
3. **Data Quality** — Sample construction, measurement error, attrition, representativeness
4. **Estimation Approach** — Specification choices, standard errors, functional form, multiple testing
5. **Robustness Checks** — Placebo tests, alternative specs, sensitivity analysis — what's missing?
6. **External Validity** — Generalizability of findings; LATE vs. ATE; local vs. broad conclusions
7. **Contribution to Literature** — Incremental vs. novel; what papers does this beat?
8. **Writing and Presentation** — Clarity, table/figure quality, abstract accuracy (minor)

Generate **7-10 major concerns** (numbered) + **5-8 minor comments** (bullets).

### Mini Mode — 5 Dimensions (Empirical Focus Only)

1. **Identification Strategy** (main focus) — Is the causal claim credible? Threats?
2. **Data Quality** — Sample construction; measurement of key variables
3. **Estimation Approach** — Major specification concerns; SE choices
4. **Missing Robustness Checks** — What should have been done but wasn't?
5. **External Validity** — Brief (1-2 points only)

Generate **3-5 major concerns** (numbered). No minor comments section.

---

## Step 4: Write the Markdown Report

Determine the output filename:
- Extract author-year from filename (e.g., `Braghieri_etal_2022_DiD.pdf` → `Braghieri2022`)
- Report path: `Referee_reports/[AuthorYear]_referee_[full|mini].md`

### Full Report Template (~2000-2500 words):

```markdown
# Referee Report: [Full Paper Title]

**Paper:** [Title as it appears in the paper]
**Authors:** [Author list]
**Date Reviewed:** [YYYY-MM-DD]
**Mode:** Full
**Reviewer:** referee-report skill

---

## Summary

[2-3 paragraph description: what the paper does, data used, method,
and main quantitative finding. Factual, no evaluation here.]

---

## Assessment of Contribution

[1 paragraph: What's genuinely new? What gap does it fill? Is the contribution
incremental or significant? Be precise about what papers it advances beyond.]

---

## Major Concerns

### MC1: [Concern Title]

[3-5 sentences: specific description of the problem, why it matters for
the paper's claims, and what the authors should do to address it.
Reference specific sections, tables, or equations where applicable.]

### MC2: [Concern Title]
[...]

[Continue for 7-10 major concerns]

---

## Minor Comments

- [Minor comment 1 — writing, presentation, or small empirical point]
- [Minor comment 2]
[5-8 bullets]

---

## Recommendation

**Decision:** [Accept / Minor Revision / Major Revision / Reject]

[2-3 sentences explaining the decision. Be direct. If rejecting, state
the fatal flaw. If requesting revision, state what must be demonstrated.]
```

### Mini Report Template (~1000-1200 words):

```markdown
# Referee Report (Mini): [Full Paper Title]

**Paper:** [Title]
**Authors:** [Author list]
**Date Reviewed:** [YYYY-MM-DD]
**Mode:** Mini (Empirical Design Focus)
**Reviewer:** referee-report skill

---

## Summary

[2-3 sentences: what the paper does and main claim.]

---

## Empirical Design Assessment

[1-2 paragraphs: overall assessment of the identification and estimation approach.
Summarize the strategy and its strengths before listing concerns.]

---

## Major Concerns

### MC1: [Concern Title]

[3-4 sentences: specific concern about identification or estimation.]

[Continue for 3-5 concerns]

---

## Recommendation

**Decision:** [Accept / Minor Revision / Major Revision / Reject]

[2-3 sentences with rationale.]
```

---

## Step 5: Write the Beamer Slide Deck

Determine the slide filename:
- If week number is known: `Slides/WeekNN_AuthorYear_referee_[full|mini].tex`
- If unknown: `Slides/AuthorYear_referee_[full|mini].tex`

**Critical constraints:**
- NO `\usepackage{biblatex}` or `\addbibresource{}` — no citations used
- NO `\cite{}`, `\textcite{}`, `\parencite{}` — use plain text (e.g., "Braghieri et al. (2022)")
- NO `subcaption` package
- NO `\pause`, `\onslide`, `\only`, `\uncover`
- Use `\ding{51}` / `\ding{55}` (pifont) for checkmarks/crosses, not raw Unicode
- Use TEXINPUTS path: `../Preambles/Presentation_template`

### Full Slide Structure (15-18 slides):

```latex
\documentclass[aspectratio=169,xcolor=dvipsnames]{beamer}
\usetheme{Simple}

\usepackage{hyperref}
\usepackage{graphicx}
\usepackage{booktabs}
\usepackage{amsmath}
\usepackage{makecell}
\usepackage{multirow}
\usepackage{array}
\usepackage{amssymb}
\usepackage{pifont}
% NO biblatex, NO subcaption

\title[Referee Report: Short Title]{\textbf{Referee Report (Mini)}}
\subtitle{[Paper Title]}
\author[]{Ruihua GUO}
\institute[]{
    \textbf{Department of Real Estate, NUS Business School} \\
    \textbf{National University of Singapore}
    \vskip 3pt
}
\date{\today}

\begin{document}

% Slide 1: Title
\begin{frame}
\titlepage
\end{frame}

% Slide 2: Paper at a Glance
\begin{frame}{Paper at a Glance}
\begin{block}{[Author(s) (Year)]}
\begin{itemize}
  \item \textbf{Data:} [source, N, period]
  \item \textbf{Method:} [identification strategy]
  \item \textbf{Main Claim:} [1-sentence main finding]
\end{itemize}
\end{block}
\end{frame}

% Slide 3: Contribution Claim
\begin{frame}{Contribution Claim}
...
\end{frame}

% Slide 4: Identification Strategy Overview
\begin{frame}{Identification Strategy}
...
\end{frame}

% Slides 5-12: One slide per major concern
% Use columns[T] to split problem (left) from required action (right)
% alertblock = SHORT headline (1-2 lines max), NOT a container for all bullets
\begin{frame}{MC[N]: [Concern Title]}
\begin{alertblock}{Core Problem}
  [1-2 sentence statement of the problem — concise]
\end{alertblock}
\vspace{0.3em}
\begin{columns}[T]
  \column{0.50\textwidth}
    \textbf{Why it matters}
    \begin{itemize}
      \item [Specific point 1]
      \item [Specific point 2]
      \item [Specific point 3 — max 3-4 bullets]
    \end{itemize}
  \column{0.46\textwidth}
    \begin{block}{Required}
      [What the authors must do — 2-3 lines]
    \end{block}
\end{columns}
\end{frame}

% Slide 13: Minor Comments
\begin{frame}{Minor Comments}
\begin{block}{Presentation and Writing}
\begin{itemize}
  \item [Minor comment 1]
  \item [Minor comment 2]
  ...
\end{itemize}
\end{block}
\end{frame}

% Slide 14-15: Recommendation
\begin{frame}{Recommendation}
\begin{alertblock}{Decision: [Accept / Minor Revision / Major Revision / Reject]}
[1-2 sentence rationale]
\end{alertblock}
\begin{block}{Path to Acceptance}
\begin{itemize}
  \item [Key requirement 1]
  \item [Key requirement 2]
\end{itemize}
\end{block}
\end{frame}

\end{document}
```

### Mini Slide Structure (8-10 slides):

Same structure but:
- Omit Contribution Claim slide
- 3-5 major concern slides (no minor comments slide)
- Condensed Recommendation slide

---

## Step 6: Compile

Run 3-pass XeLaTeX from `Slides/` (no biber needed):

```bash
cd /path/to/Slides
TEXINPUTS=../Preambles/Presentation_template:$TEXINPUTS xelatex -interaction=nonstopmode [filename].tex
TEXINPUTS=../Preambles/Presentation_template:$TEXINPUTS xelatex -interaction=nonstopmode [filename].tex
TEXINPUTS=../Preambles/Presentation_template:$TEXINPUTS xelatex -interaction=nonstopmode [filename].tex
```

If compilation fails, read the `.log` file, fix the error, and retry (max 2 attempts).

---

## Step 7: Quality Score and Summary

Score the output (0-100):

| Criterion | Weight | Check |
|-----------|--------|-------|
| Concerns are specific (not vague) | 25 | Each concern cites specific section/table/equation |
| Concerns are actionable | 20 | Each concern includes what authors must do |
| Coverage of all dimensions | 20 | All required dimensions addressed |
| Markdown report readable | 15 | Correct structure, ~target word count |
| Beamer compiles to PDF | 20 | No LaTeX errors |

Present to user:
- Report path + word count
- Slide path + page count
- Quality score
- Top 3 concerns (1-line summary each)
- Recommendation decision

**Do not present output if quality score < 80.** Loop back and improve.

---

## Principles

- **Be a harsh but fair referee.** Top-5 journals reject 90% of papers. Your job is to find the problems.
- **Be specific.** "The identification strategy is questionable" is useless. "The parallel trends assumption fails because [X]" is useful.
- **Every concern must have a suggested fix or question for authors.**
- **Do not fabricate.** If you couldn't read a section, say so. Do not invent findings.
- **Distinguish fatal from fixable.** Not everything warrants rejection.
- **Acknowledge strengths.** Even a paper with problems may have a valuable dataset or creative design.
