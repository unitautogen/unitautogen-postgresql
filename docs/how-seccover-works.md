# How seccover proves its verdicts

Plain answers to the questions people ask when they first see the seccover report. Each one describes what
the tool actually does, in the order it does it. For the command itself, see
[commands](commands.md#3-seccover---security-coverage-enterprise-licence).

## What is the tool trying to prove?

Every multi-tenant database makes one promise: a customer can see and change their own data, and nobody
else's. seccover tests that promise against your real functions, triggers, views and row-level security
policies, with real calls on a real database. Then it tells you one of two things: "we proved it holds here"
or "we could not prove it, and here is why". It never guesses.

## How is the test data seeded?

We create rows for two pretend customers, A and B, and label every row with who owns it. Only the ownership
columns, such as `tenant_id` or `user_id`, carry tenant-specific values, because those are what the security
policy reads. The other columns get simple filler values, but each seeded row also carries its own unique
marker. If a row ever shows up where it should not, the marker tells us exactly which row it was and whose.

## How is a leak detected?

We act as customer A and run the function. Then we check two things: A's results contain none of B's rows,
and B's rows in the tables are untouched. Two mechanisms back this up.

First, the seeded values are unique per row. Even if the function returns a single column, that one value is
enough to trace it back to the exact row it came from, and we know who owns that row.

Second, the stronger net: we run the function twice, once with B's rows present and once with B's rows
removed. If A gets a different answer in the two runs, the difference could only have come from B's data.
This catches indirect leaks too, such as a count or a total that changes because of another tenant's rows,
where no actual value of B appears in the output.

For functions that write, we take a snapshot of the affected tables before and after the call and compare
them. If the call touched anyone else's rows, the snapshots differ and the diff names the rows.

## Can a seeded row be present and still invisible?

Yes, and that is the one way the two-run comparison could be fooled, so we guard against it. A total ignores
a row whose amount is 0 or empty, and a count of paid invoices ignores a row whose paid flag is false. If B's
row carried such a neutral value, removing it would change nothing and a real cross-tenant total would pass.
So the filler values on B's row are never neutral: number columns get a distinct non-zero amount, and a
true/false column gets whichever value the function's own condition looks for (true for `WHERE paid`, false
for `WHERE NOT paid`), read from the function text. Columns the function never mentions are left alone.

## What if the function returns nothing, but its error gives the game away?

A function can leak without returning a row, just by failing differently for different people. Take a
function that registers a username into a table where usernames are unique across the whole database.
Customer B tries the name "alice". The database refuses: "duplicate key". Nothing was returned, but B has
learned that "alice" exists in some tenant B cannot see. The error itself is the leak.

So we check the error channel separately. For every function that inserts into a column with a uniqueness
rule, we plant a row for customer B that already holds a chosen value, then call the function as customer A
with that same value. We put the colliding row there ourselves, so the collision is guaranteed. Then we make
the same call with a fresh value that collides with nothing, as a control. If the colliding call fails in a
way that tells A the value already exists, that is a leak, marked on the INSERT cell with the channel ERROR.

This check runs on its own, independently of the read verdict. A function can be clean in what it returns -
one that always answers "created", say - and still leak here.

The limit: a uniqueness rule scoped to the tenant ("handle must be unique within a tenant") cannot leak this
way, because A's collision only ever reveals A's own rows. And the check only applies where a function
inserts into a unique column; anywhere else there is no error channel to test, and we say nothing rather
than invent a result.

## What if the function reads one row at a time? Could the calls miss the leak?

A blind call could. So we do not call blindly. For a one-row-at-a-time function we pass the rival row's own
key as the argument. If the function leaks, that is exactly the call that shows it.

Then the honesty rule. Before trusting a "no leak" result, we prove the call could actually reach that row:
the rightful owner runs the very same call and must get the row back. Owner gets it, outsider gets nothing:
that is a real proof for that path. If even the owner's call cannot reach the row, we refuse to say clean and
mark the result not testable instead. A weak probe can never produce a false green, only an honest "could not
prove it".

## How do you test a user who belongs to two tenants?

With three players. We create one user who is a member of tenant 1 and tenant 2, and we also seed rows for a
tenant 3 that this user does not belong to. It is one user holding both memberships at once, because some
policies work for a single-membership user and break, error out, or hide rows exactly when one user holds
two.

The expectation is fixed at seed time. We planted the entitled rows ourselves, one in each of the user's two
tenants, so we know their keys. We evaluate the policy's own condition with this user's identity to compute
the exact list of keys the user is entitled to, and check that both planted keys are on it. If they are not,
we do not judge at all; we mark the probe skipped or unreliable.

Then the member reads the table directly with security on, and we compare lists. A missing entitled key means
one membership's data is silently hidden: too strict. A key from tenant 3 means a leak. An exact match
confirms the union.

The function is judged separately: after the table check passes, we call the function as the same two-tenant
member and compare its keys against the direct read. Extra keys are a function-level leak. Fewer keys mean the
function silently drops one tenant's data, which we flag as a defect, not a leak.

For triggers, the same two-tenant user inserts, updates and deletes a row through them. For each write we
check that it did not error out (a trigger that looks up "the caller's tenant" expecting a single answer
crashes on a member of two tenants), that the row is visible to the writer afterward, and that the stored
tenant equals the tenant the write was meant for - so a row silently re-stamped into the wrong one of the
writer's own tenants is caught.

## Do views get the same treatment?

Yes, on both sides. A view normally runs as its owner, not as the person selecting from it, so the base
table's row security is checked against the owner - who usually sees everything. We read through every
client-reachable view as customer A and check that nothing of B's comes back.

Many views can also be written through. For each such view we push a row stamped with B's tenant through it
as A, then try to change and remove B's row through it, and watch B's rows in the base table. A view whose
writes reach B's rows is reported as leaking on those commands; a `security_invoker` view, which runs as the
caller, is reported as enforced. A view whose writes go through an `INSTEAD OF` trigger shows in both places:
on the view's row, and as a binding in the trigger section.

## Do you test the function or just the tables?

Both, and they answer different questions. The direct table reads tell us whether the policy is right. The
function calls - with row tracing, the two-run comparison and the before-and-after snapshots - tell us whether
the function is right. A green verdict needs the relevant checks on both sides to hold.

## What if the leak lands in a table your function never names?

A function can leak without mentioning the table where the damage lands. It calls a helper, the helper calls
another, and several steps down the chain something writes an audit or history row stamped with a tenant
nobody in the test belongs to.

So we follow the function into every function and trigger it calls, as deep as the chain goes, and collect
every table any of them writes. Then we run the function as customer A and watch the owner column of all
those tables at once. If a row turns up owned by a tenant that was never in the seeded world, and A did not
pass that tenant in as an argument, the call planted a row under a stranger's name in a side table. That is a
leak, and the report names the table it landed in.

## What if a trigger lets the caller choose the tenant?

Some triggers set a row's tenant not from the tenant column you write, but from another value the caller
controls: a second column in the same row, or a session setting. Such a trigger can look contained in the
obvious test, because when we stamp the tenant column with the rival's value the trigger overwrites it from
the other channel and the row lands back in our own tenant.

So we test the channel itself. We write the row honestly, our own tenant in the tenant column, and set each
caller-controlled value to the rival's tenant instead. If the row then lands in the rival's tenant, the caller
can route writes into anyone's tenant just by filling in a field or setting a variable. We mark that leaking
and name the channel that carried it.

## What do the verdicts mean?

- **LEAKING** - a call as one tenant demonstrably received or modified another tenant's data; the report
  shows which rows.
- **ENFORCED** (functions and views) / **CONTAINED** (triggers) - the probes ran, reached the other tenant's
  data on purpose, and the boundary held every time.
- **TOO STRICT** - an entitled caller was refused its own rows.
- **UNPROVEN** - a cell could not be judged: the probe could not have fired, or the test world failed to seed.
  Neither a leak nor a pass.
- **Not applicable** - this check has no honest way to run here, for example when two entitled worlds cannot
  be created under the schema's own constraints.
- **Not testable** - the probe could not reach what it needed to. An open question, never a green.
- For triggers: **UNRELIABLE** - the seed or the probe could not be set up soundly; **NOT-REACHED** - the role
  holds no grant for the firing command, so it cannot reach the trigger today. **(pinned)** means the test
  asserts this stays true, so a later `GRANT` fails the suite instead of silently opening a path.

## Is an anonymous caller who can run a function a leak?

Not by itself. Think of a self-service signup: the person creating their login has no tenant yet, so they are
anonymous by definition, and the function is meant to work for them.

So the tool does not decide whether an anonymous caller is allowed to act; that is your application's policy,
and it cannot be read off the schema. What it does hold every caller to, anonymous included, is the tenant
boundary: never see another tenant's rows, never write into them, and never learn about them through an
error. A signup function that tells a stranger "that username already exists" is allowed to run and still
leaks.

A function whose answer is always the same word, such as one that returns "created", shows its read cells as
clean by structure, not as a proven result. A constant has nothing to trace back to a row.

## What do the unit test columns mean?

Next to each verdict the report shows how much of the function's code the tests walked through: branch
coverage, line coverage, and tests passed out of tests run. *Witnesses reused* counts test rows the security
probes borrowed from the generated unit tests. These columns are there so that a clean verdict on a
half-exercised function is visible as exactly that. A plain SQL function has no branches, so one proven call
runs the whole body and counts as full coverage, labelled as such.

## Which identity do the tests run as?

Each judged row names its **Role** - the client role the verdict was produced under - and an **Entitlement**:

- *scoped* - a policy names the role, so it must get its own tenant's rows and no other;
- *deny-all* - it can call the function but no policy names it, so it must see nothing;
- *exempt* - a superuser, a `BYPASSRLS` role, or the table owner without `FORCE ROW LEVEL SECURITY`; it reads
  every row by design, so it is listed, not judged;
- *judged* - the client role the verdict was established under.

The judge refuses to run as superusers or roles that bypass row security, because a verdict produced that way
would mean nothing. Triggers run under their original permission context: we act as a realistic caller and let
the database do what it would do in production.

## Does any of this touch my data?

Your rows, no. Every probe runs inside a transaction that is rolled back. The seeded rows, the probe calls and
the write probes all disappear. What the run adds is its pgTAP test schemas, which it installs to run the tests
and drops at the end; the `testgen` helper schema the committed tests need; and, when a routine calls `now()`,
`random()` or similar, a `testgen_det` schema of frozen stand-ins that may be left in place.

## Why does this matter next to static analysis?

Static tools that scan policies and function definitions are good at raising flags - "this `SECURITY DEFINER`
function bypasses row security, look at it". That flag is a starting point, not a verdict. seccover answers it
with live evidence: a flagged function can turn out to leak nothing because its own `WHERE` clauses re-impose
the tenant boundary, and the report shows the exact calls that proved it. One kind of tool tells you where to
look; the other tells you what is actually true there.
