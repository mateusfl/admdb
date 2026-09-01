DROP TABLE IF EXISTS orders_products CASCADE;
DROP TABLE IF EXISTS orders     CASCADE;
DROP TABLE IF EXISTS products   CASCADE;
DROP TABLE IF EXISTS users      CASCADE;

CREATE TABLE users (
    id serial PRIMARY KEY,
    name text NOT NULL,
    email text NOT NULL UNIQUE,
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE products (
    id serial PRIMARY KEY,
    name text NOT NULL,
    price numeric(10,2) NOT NULL CHECK (price >= 0),
    stock integer NOT NULL DEFAULT 0 CHECK (stock >= 0),
    created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE orders (
    id serial PRIMARY KEY,
    user_id integer NOT NULL REFERENCES users(id),
    order_date timestamptz NOT NULL DEFAULT now(),
    status text NOT NULL DEFAULT 'pending'
           CHECK (status IN ('pending', 'paid', 'shipped', 'delivered', 'canceled')),
    total numeric(12,2) NOT NULL DEFAULT 0 CHECK (total >= 0)
);

CREATE TABLE orders_products (
    id serial PRIMARY KEY,
    order_id integer NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
    product_id integer NOT NULL REFERENCES products(id),
    quantity integer NOT NULL CHECK (quantity > 0),
    unit_price numeric(10,2) NOT NULL CHECK (unit_price >= 0)
);

INSERT INTO users (name, email) VALUES
    ('Ana Souza',    'ana@tads.ifrn'),
    ('Bruno Lima',   'bruno@tads.ifrn'),
    ('Carla Alves',  'carla@tads.ifrn'),
    ('Diego Santos', 'diego@tads.ifrn'),
    ('Elisa Prado',  'elisa@tads.ifrn'),
    ('Felipe Silva', 'felipe@tads.ifrn');

INSERT INTO products (name, price, stock) VALUES
    ('Notebook Dell Inspiron',            4500.00, 10),
    ('Mouse Logitech MX',                 89.90, 50),
    ('Teclado Mecânico Logitech',         349.90, 30),
    ('Monitor 27" Dell',                  1899.00, 12),
    ('Webcam HD Logitech',                259.00, 40),
    ('Headset Gamer Logitech',            499.90, 25),
    ('Cadeira Ergonômica Flexform',       1299.00,  8),
    ('SSD 1TB Kingston',                  459.00, 20),
    ('Notebook Apple Macbook Pro M5',     19999.00, 8);

INSERT INTO orders (user_id, order_date, status, total) VALUES
    (1, now() - interval '2 days',  'delivered', 4589.90),
    (2, now() - interval '5 days',  'shipped',    349.90),
    (3, now() - interval '10 days', 'paid',       618.90),
    (1, now() - interval '15 days', 'delivered', 1299.00),
    (4, now() - interval '20 days', 'paid',       459.00),
    (5, now() - interval '25 days', 'pending',    259.00),
    (2, now() - interval '40 days', 'delivered', 1899.00),
    (3, now() - interval '50 days', 'canceled',   499.90),
    (4, now() - interval '60 days', 'delivered',  349.90),
    (5, now() - interval '90 days', 'delivered', 4500.00);

INSERT INTO orders_products (order_id, product_id, quantity, unit_price) VALUES
    (1, 1, 1, 4500.00),
    (1, 2, 1,   89.90),
    (2, 3, 1,  349.90),
    (3, 5, 1,  259.00),
    (3, 3, 1,  349.90),
    (3, 2, 1,   89.90),
    (4, 7, 1, 1299.00),
    (5, 8, 1,  459.00),
    (6, 5, 1,  259.00),
    (7, 4, 1, 1899.00),
    (8, 6, 1,  499.90),
    (9, 3, 1,  349.90),
    (10, 1, 1, 4500.00);

-- 1
select *
from products
where price > 1000;

-- 2
select *
from products
order by price desc;

-- 3
update products
set price = price * 1.10
where name ilike '%dell%';

-- 4
delete from products
where name ilike '%macbook%';

-- 5
delete from products
where id = (
   select p.id
   from products p
   where not exists (
      select *
      from orders_products op
      where op.product_id = p.id
   )
   limit 1
);

-- 6
select *
from orders
where order_date >= now() - interval '30 days';

-- 7
select
   o.*,
   u.name nome_usuario
from orders o
join users u
   on u.id = o.user_id;

-- 8
select
   u.*,
   o.*
from users u
left join orders o
   on o.user_id = u.id;

-- 9
select distinct
   u.id,
   u.name,
   u.email
from users u
join orders o
   on o.user_id = u.id;

-- 10
select p.*
from products p
where not exists (
   select *
   from orders_products op
   where op.product_id = p.id
);

-- 11
select u.*
from users u
where not exists (
   select *
   from orders o
   where o.user_id = u.id
);

-- 12
select *
from products
where price > (
   select avg(price) from products
)
order by price desc;

-- 13
select
   u.id,
   u.name,
   count(o.id) total_pedidos
from users u
left join orders o
   on o.user_id = u.id
group by u.id, u.name
order by u.id;

-- 14
select
   p.id,
   p.name,
   sum(op.quantity) total_vendido
from products p
join orders_products op
   on op.product_id = p.id
group by p.id, p.name
order by total_vendido desc
limit 3;

-- 15
select
   u.id,
   u.name,
   count(o.id) quantidade_pedidos,
   coalesce(sum(o.total), 0) valor_total
from users u
left join orders o
   on o.user_id = u.id
group by u.id, u.name
order by u.id;
