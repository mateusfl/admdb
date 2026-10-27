
select pg_backend_pid();

-- =============== Questão 01 ===============

begin; 

insert into customer (store_id, first_name, last_name, email, address_id)
values (1, 'Mateus', 'Felipe', 'mateusfelipe@email.com', 1);

insert into address (address, district, city_id, phone)
-- viola regra, phone não pode ser null
values ('Rua das Flores, 100', 'Centro', 1, null);

rollback;

/* 
    O cliente não permanece na tabela. O fato de usarmos o rollback faz todo o processo 
    ser descartado até o 'begin;' no começo.
    Ele não deve ser persistido pois possuir um cliente sem endereço seria uma violação 
    das regras de negócio, então faz sentido 'esquecer tudo'.
*/

-- =============== Questão 02 ===============
 
begin; 

insert into inventory (film_id, store_id)
values (1, 1);

savepoint atualizacao;

-- erro film_id inexistente
insert into inventory (film_id, store_id)
values (9999, 1);

rollback to savepoint atualizacao;

-- ok, film_id existe
insert into inventory (film_id, store_id)
values (2, 2);

commit;

select * from inventory
order by inventory_id desc
limit 3;

/*
    Após o commit, o registro falho não permanece pois foi feito rollback até 
    o savepoint determinado antes dele. Nesse caso faz sentido manter o processo até o save pois 
    é sabido que a primeira operação de inserção deve funcionar, o risco de falha está somente após ela.
*/

-- =============== Questão 03 ===============

-- Roteiro: A começa primeiro:
delete from inventory where inventory_id = 9999;
insert into inventory (inventory_id, film_id, store_id) values (9999, 1, 1);

-- [sessão A] passo 1
begin;
select inventory_id, store_id from inventory where inventory_id = 9999 for update;

-- [sessão B] passo 2: fica aguardando a sessão A
begin;
select inventory_id, store_id from inventory where inventory_id = 9999 for update;

-- [sessão A] passo 3: commit de A
update inventory set store_id = 2 where inventory_id = 9999;
commit;

-- [sessão B] passo 4: B é liberado, vê a unidade e consegue deletar, mas na loja 2
delete from inventory where inventory_id = 9999 returning inventory_id, store_id;
commit;

-- ===========================

-- Roteiro: B começa primeiro:
delete from inventory where inventory_id = 9999;
insert into inventory (inventory_id, film_id, store_id) values (9999, 1, 1);

-- [sessão B] passo 1
begin;
select inventory_id, store_id from inventory where inventory_id = 9999 for update;

-- [sessão A] passo 2: Trava aqui esperando B
begin;
select inventory_id, store_id from inventory where inventory_id = 9999 for update;

-- [sessão B] passo 3
delete from inventory where inventory_id = 9999;
commit;

-- [sessão A] passo 4: A fica livre imediatamente, mas o select retorna 0 linhas pois a unidade foi deletada
