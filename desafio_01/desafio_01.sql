

-- =============== Questão 01 ===============

drop materialized view if exists mv_driver_season_summary;

create materialized view mv_driver_season_summary as 
select 
    r.year ano,
    d.id driver_id,
    d.full_name nome_completo,
    count(rd.race_id) total_corridas,
    count(case when rd.position_number=1 then 1 end) vitorias,
    count(case when rd.position_number<=3 then 1 end) podios,
    count(case when rd.race_reason_retired IS NOT NULL then 1 end) abandonos,
    coalesce(sum(rd.race_points), 0) pontos
from race_data rd
join race r
   on r.id = rd.race_id
join driver d
   on d.id = rd.driver_id
where rd.type = 'RACE_RESULT'
group by r.year, d.id, d.full_name
;

create unique index idx_mv_driver_season_summary_ano_driver_id
   on mv_driver_season_summary (ano, driver_id);

refresh materialized view concurrently mv_driver_season_summary;

-- explain analyse
select *
from mv_driver_season_summary
where driver_id = 'ayrton-senna'
order by ano desc
limit 10;


-- =============== Questão 02 ===============

drop table if exists points_adjustment_audit;

CREATE TABLE points_adjustment_audit (
    id         SERIAL PRIMARY KEY,
    year       INT NOT NULL,
    driver_id  VARCHAR(100) NOT NULL,
    old_points DECIMAL(8,2),
    new_points DECIMAL(8,2),
    changed_at TIMESTAMPTZ DEFAULT NOW()
);

create or replace function audit_points_adjustment()
   returns trigger
   language plpgsql
as $$
begin
   insert into points_adjustment_audit (year, driver_id, old_points, new_points)
   values (NEW.year, NEW.driver_id, OLD.points, NEW.points);

   return NEW;
end;
$$;

drop trigger if exists trg_audit_points_adjustment on season_driver_standing;

create trigger trg_audit_points_adjustment
after update on season_driver_standing
for each row
when (NEW.points != OLD.points)
execute function audit_points_adjustment();

-- não é para adicionar nada no audit
update season_driver_standing
set points = points
where year = 1993 and driver_id = 'ayrton-senna';

update season_driver_standing
set points = points + 100
where year = 1993 and driver_id = 'ayrton-senna';

select * from points_adjustment_audit;
