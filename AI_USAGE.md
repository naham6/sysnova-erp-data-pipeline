# AI_USAGE.md  (only if you used AI; copy to repo root as `AI_USAGE.md` and fill in)

Using AI is optional, and honest disclosure is never penalised. See `AI_AGENT_GUIDELINE.md`.

## 1. Tools and models used
| Tool | Model / version | Used for |
|---|---|---|
| Claude Code | Sonnet | Doing part as agent |
| Gemini | Hydrogen | Most of the parts

## 2. Where AI helped, by task
- Task 1: Understanding the task in summary and specific rules. Making the script.
- Task 2: Writing the docs in plain and understanding way.
- Task 3: Designing the transactional SQL script and learning and applying constraint logics. 
- Task 4 (queries): Creating queries including formula and logics to generate report.
- Task 5 / optional extras:
- README / docs: Readme.

## 3. Significant prompts (3-5, copy/paste) and what you did with the answer
1. **Prompt:**
   **Result and what I changed:**
2. ...

## 4. Times the AI was wrong or misleading (at least 2) and how I caught it
1. **What went wrong:** The AI generated a profiling query joining `raw_invoices` and `raw_orders` that referenced `order_id` without specifying a table.
   **How I noticed / verified:** Executing the script.
   **Fix:** Updated the script to explicitly qualify the column with the table alias (`i.order_id`).
2. **What went wrong:** The AI claimed in documentation that `customer_changes.csv` contained changes for 63 unique customers.
**How I noticed / verified:**When inspecting the raw CSV dataset using Pandas, I checked the unique customer count (`df['customer_id'].nunique()`) and verified there were actually 60 unique customers.
**Fix:**Manually corrected the documentation.

## 5. What I deliberately did myself (and why)
- **Database Schema Design:** Learned and wrote the database architecture manually to ensure full functionalities of foreign key relationships, behaviors, and logging.
- **Business Logic & Validation:** I personally verified all row-count reconciliations and tested the report queries to guarantee financial accuracy. Utilized AI with manual validation on data and logics.

## 6. Declaration
I reviewed and understand all submitted code and can explain it. I did not get help from another person.
Name: NAHAM   Date: 14/11/26
