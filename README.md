# Data Pipeline Approach

## Languages
- I started this using a notebook approach, but my compute_wh failed to initialize a few times so I quickly switched to just SQL
- Later on I was able to get my compute_wh running, so I did some proof of concept presentation layer selects and visuals in notebooks

## Assumptions about data files and ingestion tasks
- I'm operating on the assumption that the data files will be replaced daily
- I have set up nightly cron tasks to move data from ingestion to presentation
- In a production environment I would utilize 'after' more judiciously to make these run in sequence
- For now I have just set them to a 5 minute interval
- If it is a different interval the database tasks can be modified to reflect that and not run unnecessarily
- I've manually uploaded these files into a snowflake stage
- In a real production system they would ideally be pushed from a server, or uploaded when ready
- If these weren't to be pushed on an interval, I would refactor the ingestion processes to ignore old files as to not use up compute time

## Order of files/tables in pipeline
1. **Customers** - will be loaded first, as that is the top of the data hierarchy. Policies has a fk to customers
2. **Policies** - will be loaded second. Claims, payments, and endorsements have a fk to policies
3. **Claims/Payments/Endorsements** - the order of these doesn't matter between them, but they will go in the order as specified here

## Pipeline order and logic
1. **Load raw data into ingest database.** This data will be deleted nightly when it grabs the current file

2. **Merge from ingest into collect database.**
   This is a secondary ingestion with version history and timestamps. Only inserts new row if there is new data or if data has changed.
   > NOTE: Ideally steps #1 and #2 would be in one step, but I haven't found a clean way to do that yet
   > NOTE: I have found this practice helpful in tracking down data errors after the fact and finding when they occurred.

3. **Merge from collect into transform database.**
   - Selects the most recent version of each row
   - Selects only non-orphaned data
   - Output orphaned keys into orphaned_data table
   - Output cleaned keys into cleaned_data table
   > COULD DO: generate an alert based on the contents of the orphaned_data table (likely ignore policy_id=999999)

4. **Overwrite from transform into present database.** This is where we answer the questions:
   - [x] Which policy types are generating the highest loss ratios?
   - [x] How do claims and payments trend across different policy segments?
   - [x] Which customers or policy groups may represent elevated financial risk?
   - [x] How can leadership monitor policy profitability and claims exposure over time?

## Bad data handling
- I understand that snowflake has built-in error handling and tracking, but I'm reverting to the more basic SQL methods that I know and have used in the past. Maslow was right about hammers and nails.
- I've noted below how I'm currently handling each individual piece of bad data, but there are certainly other approaches that may be more appropriate in a full implementation, likely leaning heavily on the native snowflake tracking methods.
- There are additional bad data possibilities that I have not accounted for. If needed I could indicate missing data for each individual column.
- This being a quick turnaround assignment, I've opted to handle bad data by making a note in the cleaned_data or orphaned_data table, and not migrating it into the transform tables.
- From those tables I would set an alert or send an email to the appropriate individuals so that they can update the incoming files where necessary, or indicate to the data users that there may be incomplete data.

## Proof of concept
- Once all of the data has been generated in the presentation layer, I will create proof of concept notebooks to make sure the data is in a format that can be used to create visualizations for business use-case consumption.

---

# Observations/Questions

## Premium definition
**Assumption:** policy premium is a yearly amount (consistent with what I understand about insurance)

## Policies without payments
- **Assumption:** There were no payments in the window of time for this data set
- **Assumption:** Payments are the representation of income

## Claims outside of effective_date - expiration_date
**Assumption:** This is common, considering the large number of data that fall into this category

## Loss ratio definition
**Assumption:** claims / (payments + endorsements) over a period of time

## Elevated financial risk definition
**Assumption:** high loss ratio across a segment

## Endorsement definition
- **Assumption:** I will assume this data is correct, and add to payment amounts to calculate income
- **Assumption:** Negative amounts decrease from income and positive amounts add to it
- **Note:** This can easily be switched in the calculation functions

---

# Data Issues

## FOUND: claims contains a record with policy_id = 999999
- **SOLUTION:** remove orphaned claims records in claims_transform process
- **SOLUTION:** flag the record in the orphaned_data table
- **ALTERNATIVE SOLUTION:** keep the record and create a 'dummy' policy with the indicated ID
> NOTE: in the event that a claim has a legitimate policy_id, but that ID is missing, this process will include it once the policy_id shows up in the policy table

> NOTE: since there was one I'm concerned there may be more in the future that aren't as obviously illegitimate

## FOUND: positive and negative values mixed in endorsements data
- **SOLUTION:** at this time, with my incomplete knowledge of the data I will assume it is legitimate
> NOTE: in a production system I would seek guidance from the data creator
- **POTENTIAL ALTERNATIVE:** switch the value to positive for Coverage Increase representing an increase in income
- **POTENTIAL ALTERNATIVE:** switch the value to negative for Coverage Decrease representing a decrease in income
- **POTENTIAL ALTERNATIVE:** switch the value to negative for Cancellation representing a decrease in income

## FOUND: -500 value in payments
- **SOLUTION:** remove where payment_amount < 0 in payments_transform process
- **ALTERNATIVE:** switch the value to positive though I believe this is the better solution at this time
- **TO DO:** flag the record in the cleaned_data table

## FOUND: policy 21 has an expiration_date before effective_date
- **SOLUTION:** flagged as incorrect in cleaned_data table and fixed later
- **PREVIOUS SOLUTION:** remove where expiration_date less than effective_date in policies_transform process
> NOTE: I didn't like the solution to just delete the record as it could negatively affect downstream reporting

> NOTE: Since there were no questions that I believe are affected by policy begin and end dates, this shouldn't affect anything in my data sets. It should be noted and fixed, but isn't a fatal error in my opinion.

> NOTE: in a real pipeline, I would have discussions about source and destination with stakeholders to make sure the data is in the best format, whether that be eliminating the bad data, or pointing it at a 'dummy'/'unknown' foreign key.
