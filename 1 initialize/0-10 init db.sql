--drop database rli;
create database if not exists rli;

create schema if not exists rli.ingest;
create schema if not exists rli.collect;
-- drop schema rli.transform;
create schema if not exists rli.transform;
-- drop schema rli.present;
create schema if not exists rli.present;