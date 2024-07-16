/*Напишите SQL-скрипт, который потокобезопасно в рамках транзакции создает новое бронирование. Скрипт должен включать:
    Создание нового бронирования.
    Создание нового билета.
    Привязка билета к перелету.*/


begin transaction;
do
$$
	declare 
		booking_r varchar(6) = '123459';
		ticket_num varchar(13) = '1234563435';
	begin
		insert into bookings(book_ref, book_date, total_amount)
		values (booking_r, current_date, 42069);
	
		insert into tickets (ticket_no, book_ref, passenger_id, passenger_name, contact_data)
		values (ticket_num, booking_r, 1, 'SLOBODAN MILOSCEVIC', '{"passport": "yes", "sex": "no"}');
	
		insert into ticket_flights (ticket_no, flight_id, fare_conditions, amount)
		values (ticket_num, 1228, 'Comfort', 5000);
	
		exception
			when others then
			raise notice 'Что-то пошло не так: %', SQLERRM;
			return;
	end	
$$;
commit;


/*Напишите SQL-скрипт, который потокобезопасно в рамках транзакции оформляет посадку пассажира на самолет. Скрипт должен включать:
    Проверку существования рейса.
    Проверку билета у пассажира на рейс.
    Создание нового посадочного талона.*/

begin transaction;
do
$$
	declare 
		ticket_num varchar(13);
		flight_togo int;
	begin

		select t.ticket_no 
		into ticket_num
		from tickets t 
		where t.passenger_name = 'SLOBODAN MILOSCEVIC';
		
		if ticket_num is null then
			raise exception 'Нет билета!';
		end if;
		
		select tf.flight_id 
		into flight_togo
		from ticket_flights tf 
		where tf.ticket_no = ticket_num;
		
		if flight_togo is null then
			raise exception 'Рейса нет!';
		end if;
		
		if not exists
		(select 1
		from boarding_passes s
		where s.ticket_no = ticket_num 
		and s.flight_id = flight_togo)
		then
			insert into boarding_passes (ticket_no, flight_id, boarding_no, seat_no)
			select ticket_num, flight_togo, 1, s2.seat_no 
			from seats s2
			where s2.fare_conditions = 'Comfort'
			limit 1;
		
			raise info 'Посадочный создан!';
		
		end if;

		exception
			when others then
			raise notice 'Ошибка: %', SQLERRM;
			return;
	
	end	
$$;
commit;

----------------------------------------------------------------------------------------------------------------------------------
/*Напишите запрос для поиска билетов по имени пассажиров. Оптимизируйте скорость его выполнения.
    Приложите результаты выполнения команд EXPLAIN ANALYZE до и после оптимизации.*/
	
	explain analyze
	select *
	from tickets t 
	where t.passenger_name ilike 'dmitriy%'
	
	/*Gather  (cost=1000.00..72077.24 rows=62734 width=104) (actual time=0.437..1153.087 rows=62987 loops=1)
	  Workers Planned: 2
	  Workers Launched: 2
	  ->  Parallel Seq Scan on tickets t  (cost=0.00..64803.84 rows=26139 width=104) (actual time=0.372..1141.785 rows=20996 loops=3)
	        Filter: (passenger_name ~~* 'dmitriy%'::text)
	        Rows Removed by Filter: 962290
	Planning Time: 0.202 ms
	Execution Time: 1154.973 ms*/
	
	
	
	-- поиск по тексту, подойдет gin индекс, используя триаграммы
	create extension pg_trgm; 
	create index idx_tickets_passenger_name_text on tickets using GIN(passenger_name gin_trgm_ops);
	
	explain analyze
	select *
	from tickets t 
	where t.passenger_name ilike 'dmitriy%'
	
	
	/*Bitmap Heap Scan on tickets t  (cost=654.13..53511.35 rows=62734 width=104) (actual time=26.319..153.395 rows=62987 loops=1)
	  Recheck Cond: (passenger_name ~~* 'dmitriy%'::text)
	  Rows Removed by Index Recheck: 1445
	  Heap Blocks: exact=36233
	  ->  Bitmap Index Scan on idx_tickets_passenger_name_text  (cost=0.00..638.45 rows=62734 width=0) (actual time=21.155..21.155 rows=64432 loops=1)
	        Index Cond: (passenger_name ~~* 'dmitriy%'::text)
	Planning Time: 0.295 ms
	Execution Time: 154.899 ms*/



