-- restore banco: pg_restore -h 127.0.0.1 -U postgres -d dvdrental dvdrental.tar

-- ==================== 1 ====================
drop view if exists v_staff_performance;

create view v_staff_performance as
select
   s.staff_id,
   s.first_name || ' ' || s.last_name nome_completo,
   ci.city || ', ' || co.country endereco_loja,
   coalesce(r.total_locacoes, 0) total_locacoes,
   coalesce(p.total_arrecadado, 0) total_arrecadado
from staff s
join store st
   on st.store_id = s.store_id
join address a
   on a.address_id = st.address_id
join city ci
   on ci.city_id = a.city_id
join country co
   on co.country_id = ci.country_id
left join (
   select staff_id, count(*) total_locacoes
   from rental
   group by staff_id
) r
   on r.staff_id = s.staff_id
left join (
   select staff_id, sum(amount) total_arrecadado
   from payment
   group by staff_id
) p
   on p.staff_id = s.staff_id;

select *
from v_staff_performance
order by staff_id;

-- ==================== 2 ====================
drop materialized view if exists mv_category_total_sales;

create materialized view mv_category_total_sales as
select
   c.name categoria,
   coalesce(sum(p.amount), 0) total_receita
from category c
left join film_category fc
   on fc.category_id = c.category_id
left join inventory i
   on i.film_id = fc.film_id
left join rental r
   on r.inventory_id = i.inventory_id
left join payment p
   on p.rental_id = r.rental_id
group by c.name;

create unique index idx_mv_category_total_sales_categoria
   on mv_category_total_sales (categoria);

refresh materialized view concurrently mv_category_total_sales;

select *
from mv_category_total_sales
order by total_receita desc;

-- ==================== 3 ====================
drop index if exists idx_rental_return_date;

create index idx_rental_return_date
   on rental (return_date)
   where return_date is null;

explain analyze
select
   rental_id,
   rental_date,
   inventory_id,
   customer_id
from rental
where return_date is null;

-- ==================== 4 ====================
drop index if exists idx_film_description_gin;

create index idx_film_description_gin
   on film using gin (to_tsvector('english', description));

explain analyze
select
   film_id,
   title,
   description
from film
where to_tsvector('english', description) @@ to_tsquery('english', 'documentary | drama');

-- ==================== 5 ====================
-- customer_id vem primeiro pois é o filtro de igualdade, então o índice localiza de uma vez o trecho do cliente. 
-- dentro dele as linhas já estão por payment_date desc, então não precisa de sort. 
-- Com payment_date na frente, os pagamentos de um
-- cliente ficariam espalhados pelo índice todo.
drop index if exists idx_payment_customer_payment_date;

create index idx_payment_customer_payment_date
   on payment (customer_id, payment_date desc);

explain analyze
select *
from payment
where customer_id = 1
order by payment_date desc;

-- ==================== 6 ====================
drop index if exists idx_customer_email_lower;

create index idx_customer_email_lower
   on customer (lower(email));

explain analyze
select *
from customer
where lower(email) = lower('MARY.SMITH@sakilacustomer.org');

-- ==================== 7 ====================
create or replace function check_rental_dates()
   returns trigger
   language plpgsql
as $$
begin
   if NEW.return_date is not null and NEW.return_date < NEW.rental_date then
      raise exception 'return_date anterior ao rental_date (rental_date: %, return_date: %)',
         NEW.rental_date, NEW.return_date;
   end if;

   return NEW;
end;
$$;

drop trigger if exists trg_check_rental_dates on rental;

create trigger trg_check_rental_dates
before insert or update on rental
for each row
execute function check_rental_dates();

begin;

update rental
set return_date = rental_date + interval '3 days'
where rental_id = 1
returning rental_id, rental_date, return_date;

rollback;

begin;

update rental
set return_date = rental_date - interval '1 day'
where rental_id = 1;

rollback;

-- ==================== 8 ====================
drop table if exists film_cost_audit;

create table film_cost_audit (
   film_id int not null references film(film_id),
   old_cost numeric(5,2),
   new_cost numeric(5,2),
   changed_at timestamptz default now()
);

create or replace function log_film_cost_changes()
   returns trigger
   language plpgsql
as $$
begin
   insert into film_cost_audit (film_id, old_cost, new_cost)
   values (NEW.film_id, OLD.replacement_cost, NEW.replacement_cost);

   return NEW;
end;
$$;

drop trigger if exists trg_log_film_cost_changes on film;

create trigger trg_log_film_cost_changes
after update on film
for each row
when (NEW.replacement_cost != OLD.replacement_cost)
execute function log_film_cost_changes();

begin;

update film
set rental_rate = rental_rate
where film_id = 1;

update film
set replacement_cost = replacement_cost + 5
where film_id = 1;

select *
from film_cost_audit;

rollback;

-- ==================== 9 ====================
create or replace function prevent_language_del()
   returns trigger
   language plpgsql
as $$
begin
   if exists (select 1 from film where language_id = OLD.language_id) then
      raise exception 'Não é permitido excluir o idioma "%" porque existem filmes cadastrados com ele (language_id: %)',
         trim(OLD.name), OLD.language_id;
   end if;

   return OLD;
end;
$$;

drop trigger if exists trg_prevent_language_del on language;

create trigger trg_prevent_language_del
before delete on language
for each row
execute function prevent_language_del();

begin;

delete from language
where language_id = 2
returning language_id, name;

rollback;

begin;

delete from language
where language_id = 1;

rollback;

-- ==================== 10 ====================
drop table if exists customer_rental_stats;

create table customer_rental_stats (
   customer_id int primary key references customer(customer_id),
   total_rentals int not null default 0
);

insert into customer_rental_stats (customer_id, total_rentals)
select
   c.customer_id,
   count(r.rental_id)
from customer c
left join rental r
   on r.customer_id = c.customer_id
group by c.customer_id;

create or replace function update_customer_rental_stats()
   returns trigger
   language plpgsql
as $$
begin
   if exists (select 1 from customer_rental_stats where customer_id = NEW.customer_id) then
      update customer_rental_stats
         set total_rentals = total_rentals + 1
         where customer_id = NEW.customer_id;
   else
      insert into customer_rental_stats (customer_id, total_rentals)
      values (NEW.customer_id, 1);
   end if;

   return NEW;
end;
$$;

drop trigger if exists trg_update_customer_rental_stats on rental;

create trigger trg_update_customer_rental_stats
after insert on rental
for each row
execute function update_customer_rental_stats();

begin;

select *
from customer_rental_stats
where customer_id = 1;

insert into rental (rental_date, inventory_id, customer_id, staff_id)
values (now(), 1, 1, 1);

select *
from customer_rental_stats
where customer_id = 1;

rollback;
