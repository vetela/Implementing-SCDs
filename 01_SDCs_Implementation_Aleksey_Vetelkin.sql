-- Drop the DimEmployee table if it already exists
drop table if exists dimemployee;

-- Remove any existing primary key constraint from DimEmployee
alter table if exists dimemployee
drop constraint if exists dimemployee_pkey;

-- Add necessary columns for SCD Type 2 implementation
alter table if exists dimemployee
add column startdate timestamp,       -- Start date for the record's validity
add column enddate timestamp,         -- End date for the record's validity
add column iscurrent boolean default true,  -- Flag to indicate if the record is the current one
add column employeehistoryid serial primary key;  -- Surrogate key for the historical record

-- Initialize the surrogate key for existing records
update dimemployee
set employeehistoryid = default;

-- Set start date to hire date and end date to a far future date for existing records
update dimemployee
set startdate = hiredate,
    enddate = '9999-12-31';

-- Create a function to handle updates for SCD Type 2
create or replace function employees_update_function()
returns trigger as $$
begin
    -- Check if the title or address has changed and the record is the current one
    if (old.title <> new.title or old.address <> new.address) and old.iscurrent and new.iscurrent then
        -- Mark the old record as not current and set its end date
        update dimemployee
        set enddate = current_timestamp,
            iscurrent = false,
            title = old.title,
            address = old.address
        where employeeid = old.employeeid and iscurrent = true;

        -- Insert a new record with the updated details and a new surrogate key
        insert into dimemployee (employeeid, lastname, firstname, title, birthdate, hiredate, address, city, region, postalcode, country, homephone, extension, startdate, enddate, iscurrent)
        values (old.employeeid, old.lastname, old.firstname, new.title, old.birthdate, old.hiredate, new.address, old.city, old.region, old.postalcode, old.country, old.homephone, old.extension, current_timestamp, '9999-12-31', true);
    end if;
    return new;
end;
$$ language plpgsql;

-- Drop the trigger if it already exists to avoid duplicates
drop trigger if exists employees_update_trigger on dimemployee cascade;

-- Create a trigger that calls the update function after each update on DimEmployee
create trigger employees_update_trigger
after update on dimemployee
for each row
execute function employees_update_function();

-- Example update to change the address of a specific employee
update dimemployee
set address = 'Barcelona'
where firstname = 'Lamine' and lastname = 'Yamal' and iscurrent = true;

-- Example update to change the title of a specific employee
update dimemployee
set title ='Divine'
where firstname = 'Maksim' and lastname = 'Kiselev' and iscurrent = true;
