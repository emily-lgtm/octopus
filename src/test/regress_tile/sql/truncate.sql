-- Test basic TRUNCATE functionality.
CREATE TABLE truncate_a (col1 integer primary key);
INSERT INTO truncate_a VALUES (1);
INSERT INTO truncate_a VALUES (2);
SELECT * FROM truncate_a;
-- Roll truncate back
BEGIN;
TRUNCATE truncate_a;
ROLLBACK;
SELECT * FROM truncate_a;
-- Commit the truncate this time
BEGIN;
TRUNCATE truncate_a;
COMMIT;
SELECT * FROM truncate_a;
DROP TABLE truncate_a;

-- Test TRUNCATE with inheritance

CREATE TABLE trunc_f (col1 integer primary key);
INSERT INTO trunc_f VALUES (1);
INSERT INTO trunc_f VALUES (2);

CREATE TABLE trunc_fa (col2a text) INHERITS (trunc_f);
INSERT INTO trunc_fa VALUES (3, 'three');

CREATE TABLE trunc_fb (col2b int) INHERITS (trunc_f);
INSERT INTO trunc_fb VALUES (4, 444);

CREATE TABLE trunc_faa (col3 text) INHERITS (trunc_fa);
INSERT INTO trunc_faa VALUES (5, 'five', 'FIVE');

BEGIN;
SELECT * FROM trunc_f;
TRUNCATE trunc_f;
SELECT * FROM trunc_f;
ROLLBACK;

BEGIN;
SELECT * FROM trunc_f;
TRUNCATE ONLY trunc_f;
SELECT * FROM trunc_f;
ROLLBACK;

BEGIN;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
TRUNCATE ONLY trunc_fb, ONLY trunc_fa;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
ROLLBACK;

BEGIN;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
TRUNCATE ONLY trunc_fb, trunc_fa;
SELECT * FROM trunc_f;
SELECT * FROM trunc_fa;
SELECT * FROM trunc_faa;
ROLLBACK;

DROP TABLE trunc_f CASCADE;

-- Test ON TRUNCATE triggers

CREATE TABLE trunc_trigger_test (f1 int, f2 text, f3 text);
CREATE TABLE trunc_trigger_log (tgop text, tglevel text, tgwhen text,
        tgargv text, tgtable name, rowcount bigint);

CREATE FUNCTION trunctrigger() RETURNS trigger as $$
declare c bigint;
begin
    execute 'select count(*) from ' || quote_ident(tg_table_name) into c;
    insert into trunc_trigger_log values
      (TG_OP, TG_LEVEL, TG_WHEN, TG_ARGV[0], tg_table_name, c);
    return null;
end;
$$ LANGUAGE plpgsql;

-- basic before trigger
INSERT INTO trunc_trigger_test VALUES(1, 'foo', 'bar'), (2, 'baz', 'quux');

CREATE TRIGGER t
BEFORE TRUNCATE ON trunc_trigger_test
FOR EACH STATEMENT
EXECUTE PROCEDURE trunctrigger('before trigger truncate');

SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;
TRUNCATE trunc_trigger_test;
SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;

DROP TRIGGER t ON trunc_trigger_test;

truncate trunc_trigger_log;

-- same test with an after trigger
INSERT INTO trunc_trigger_test VALUES(1, 'foo', 'bar'), (2, 'baz', 'quux');

CREATE TRIGGER tt
AFTER TRUNCATE ON trunc_trigger_test
FOR EACH STATEMENT
EXECUTE PROCEDURE trunctrigger('after trigger truncate');

SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;
TRUNCATE trunc_trigger_test;
SELECT count(*) as "Row count in test table" FROM trunc_trigger_test;
SELECT * FROM trunc_trigger_log;

DROP TABLE trunc_trigger_test;
DROP TABLE trunc_trigger_log;

DROP FUNCTION trunctrigger();

-- test TRUNCATE ... RESTART IDENTITY
CREATE SEQUENCE truncate_a_id1 START WITH 33;
CREATE TABLE truncate_a (id serial,
                         id1 integer default nextval('truncate_a_id1'));
ALTER SEQUENCE truncate_a_id1 OWNED BY truncate_a.id1;

INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

TRUNCATE truncate_a;

INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

TRUNCATE truncate_a RESTART IDENTITY;

INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

CREATE TABLE truncate_b (id int GENERATED ALWAYS AS IDENTITY (START WITH 44));

INSERT INTO truncate_b DEFAULT VALUES;
INSERT INTO truncate_b DEFAULT VALUES;
SELECT * FROM truncate_b;

TRUNCATE truncate_b;

INSERT INTO truncate_b DEFAULT VALUES;
INSERT INTO truncate_b DEFAULT VALUES;
SELECT * FROM truncate_b;

TRUNCATE truncate_b RESTART IDENTITY;

INSERT INTO truncate_b DEFAULT VALUES;
INSERT INTO truncate_b DEFAULT VALUES;
SELECT * FROM truncate_b;

-- check rollback of a RESTART IDENTITY operation
BEGIN;
TRUNCATE truncate_a RESTART IDENTITY;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;
ROLLBACK;
INSERT INTO truncate_a DEFAULT VALUES;
INSERT INTO truncate_a DEFAULT VALUES;
SELECT * FROM truncate_a;

DROP TABLE truncate_a;

SELECT nextval('truncate_a_id1'); -- fail, seq should have been dropped

-- partitioned table
CREATE TABLE truncparted (a int, b char) PARTITION BY LIST (a);
-- error, can't truncate a partitioned table
TRUNCATE ONLY truncparted;
CREATE TABLE truncparted1 PARTITION OF truncparted FOR VALUES IN (1);
INSERT INTO truncparted VALUES (1, 'a');
-- error, must truncate partitions
TRUNCATE ONLY truncparted;
TRUNCATE truncparted;
DROP TABLE truncparted;

DROP TABLE ref_c;