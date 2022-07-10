--ПРИЛОЖЕНИЕ 2
--Студент Куленёнок И. А.

--Задание 1
/* Подзапросом находим количество аэропортов в каждм городе с помощью оператора count и группируем по городам.
Затем осовным запросом с помощью Where выбираем города, где кол-во аэропортов > 1. Выводим название городов и кол-во аэропортов в них. */

select *
from (select city, count(airport_name) as co
	from airports
	group by city) p1
where co > 1

--Задание 2
/* В подзапросе с помощью оконной функции высавляем первый номер всем самолетам, имеющим максимальную дальнось перелета,
применяем dense_rank() на случай, если таких появится несколько и сразу джоиним таблицу flights по столбцу aircraft_code.
В основном запрое берем данные из подзапроса, отбирае по dense_rank() = 1 и выводим только уникальные коды аэропортов вылета */

select distinct p1.departure_airport
from (select f.departure_airport, 
		dense_rank() over(order by "range" desc) as ra
	from aircrafts a
	join flights f on f.aircraft_code = a.aircraft_code) p1
where p1.ra = 1

--Задание 3
/* В начале отбираем все рейсы, самолеты по которым либо вылетели, либо уже приземлились.
 Затем выбираем колонки с id рейса и колнку с расчетом вреени задержки (актуальное время - планируемое время).
 После сортируем по времени задержки от большего к меньшему и оператором limit вывоим только первые 10 записей
 */

select flight_id, (actual_departure - scheduled_departure) as time1 
from flights f 
where status = 'Arrived' or status = 'Departed'
order by time1 desc
limit 10

--Задание 4
/* Используем фулл джоин, так как нам необходимо получить NULL в том случае, если по бронированию нет билета либо посадочного талона.
Данные  отбираем только те значения,
где вместо номера билта получили NULL, выводим номера бронирований, с помощью дистинкт только униальные.
 */

select distinct b.book_ref
from bookings b 
full join tickets t on t.book_ref = b.book_ref 
full join boarding_passes bp on bp.ticket_no = t.ticket_no 
where bp.ticket_no is null

--Задание 5

with c1 as ( --СТЕ
	select f.flight_id,
		f.departure_airport,
		f.actual_departure,
		(count(s.seat_no) - count(bp.seat_no)) as free_seats, --считаем кол-во свободных мест
		count(s.seat_no) as seat1 -- считаем кол-во мест в самолете
	from flights f --данные берем из таблицы flights
	join seats s on s.aircraft_code = f.aircraft_code --Джойним с таблицей seats по столбцу aircraft_code
	left join boarding_passes bp on bp.seat_no = s.seat_no and bp.flight_id = f.flight_id --Джойним boarding_passes по столбцам seat_no и flight_id
	group by f.flight_id, f.departure_airport, f.actual_departure) --группируем в связи с использованием агрегатных функций
select c1.flight_id,
	c1.departure_airport,
	c1.actual_departure,
	free_seats,
	round(((free_seats * 100)::float / seat1)::numeric(7,4), 1) as percents, --считаем процентное соотношение, для боле точного расчета переводим вначале во флоат, а затем перед округлением в numeric
	(sum(count(bp.ticket_no)) over(partition by c1.departure_airport, c1.actual_departure::date order by c1.actual_departure)) as cumul -- оконная функция для подсчета накопительного итога  с групировкой вначале по аэропорту вылета, затем по дате вылета в типе данных "дата" и сортировка по дате вылета в типе timestamptz
from c1
left join boarding_passes bp on bp.flight_id = c1.flight_id --снова джойним боардинг пасес, так как считаю, что стоит учитывать вариант, при котром билет был выдан (например на маленького ребенка), а место он не занимает. В связи с этим в оконной функции беру именно ticket_no
group by c1.departure_airport, c1.actual_departure, c1.flight_id, c1.free_seats, c1.seat1 --группировка в связи с использованием агрегатной ф-ции

--Задание 6
/* Данные берем из таблицы перелетов, выбираем модель самолетов и далее считаем процентное соотношение след. образом:
 * Кол-во перелетов по каждой модели самолетов умножаем на 100, приводим к формату флоат, делим на кол-во всех перелетов (для этого создан подзапрос)
 *  и приводим к типу данных numeric, чтоб округлить до 2х знаков после запятой оператором round. Групируем по модели самолета.
 */
select aircraft_code, round(((count(flight_id) * 100)::float / (select count(flight_id) from flights))::numeric(7,4), 2)
from flights f 
group by aircraft_code

--Задание 7
/* В первом cte находим самый дорогой билет на эконом-класс для каждого рейса.
 * Во втором cte находим самый дешевый билет на бизнесс-класс для каждого рейса.
 * В основном запросе берем данные из cte1, джойним cte2, flights и airports, чтоб вывести именно города аэропортов прибытия.
 * Проверяем по условию, что разность между самым дешевым бизнессом и самым дорогим эономом <0.
 * Полученные значения городов в уникальном виде выводим.
 */
with c1 as(
	select flight_id, fare_conditions, max(amount) as econom
	from ticket_flights tf
	where fare_conditions = 'Economy'
	group by flight_id, fare_conditions),
c2 as(
	select flight_id, fare_conditions, min(amount) as business
	from ticket_flights tf 
	where fare_conditions = 'Business'
	group by flight_id, fare_conditions)
select distinct a.city
from c1
join c2 on c1.flight_id = c2.flight_id
join flights f on c1.flight_id = f.flight_id
join airports a on a.airport_code = f.arrival_airport 
where (c2.business - c1.econom) < 0

--Задание 8
/* В первом представлении находим все имеющиеся города откуда вылетают рейсы (берем именно уникальные номера рейсов, для дальнейшего верного соединения в основном запросе)
 * Во втором представлении находим все имеющиеся города куда прилетают рейсы (берем именно уникальные номера рейсов, для дальнейшего верного соединения в основном запросе)
 * В третьем представлении находим все возможные пары городов.
 * В осн. запросе из множества, найденного в третьем представлении вычетаем множество из первого и второго представления, соединенных по типу inner join
 */
create view task_1 as
	select distinct f.flight_no,
		a.city 
	from flights f 
	join airports a on f.departure_airport = a.airport_code
	order by f.flight_no
	
create view task_2 as
	select distinct f.flight_no,
		a.city 
	from flights f 
	join airports a on f.arrival_airport = a.airport_code
	order by f.flight_no

create view task_3 as
	select a.city as c1 , a2.city as c2
	from airports a, airports a2
	where a.city <> a2.city
	
select *
from task_3
except
select task_1.city, task_2.city
from task_1 join task_2 on task_1.flight_no = task_2.flight_no

--Задание 9
/* В первом сте находим все аэропорты вылетов по уникальным рейсам, также берем информацию о широте, долготе такого аэропорта,
 * дополнительно в этом же сте джойним таблицу с самолетами для получения максимальной альности перелета, самолетов обслуживающих данные рейсы.
 * Во втором сте находим все аэропорты прилетов по уникальным рейсам, также берем информацию о широте, долготе такого аэропорта.
 * В третьем сте переводим долготу и широту из градусов в радианы и джойним сте1 и сте2 для получения списка маршрутов.
 * В четвертом сте рассчитываем расстояние ежду аэропортами, округляем до 3 знаков после запятой (до метров).
 * Основным запрсом выводим маршруты, расстояние между аэропортами, расстояние которое может преодолеть самолет, обслуживающий данный рейс, разницу между ними и
 * с помощью условног выражения case проверяем, долетит ли самолет от аэропорта вылета до конечного аэропорта.
 */
	
with c1 as(select distinct f.flight_no,
		a.airport_name,
		a.longitude,
		a.latitude,
		ai."range" 
	from flights f 
	join airports a on f.departure_airport = a.airport_code
	join aircrafts ai on ai.aircraft_code = f.aircraft_code 
	order by f.flight_no),
c2 as(select distinct f.flight_no,
		a.airport_name,
		a.longitude,
		a.latitude
	from flights f 
	join airports a on f.arrival_airport = a.airport_code
	order by f.flight_no),
c3 as (select c1.airport_name as air1, c2.airport_name as air2,
		radians(c1.longitude) as long1, radians(c1.latitude) as lat1,
		radians(c2.longitude) as long2, radians(c2.latitude) as lat2,
		c1."range" as dist_air
	from c1 join c2 on c1.flight_no = c2.flight_no),
c4 as (select (round(((acos(sin(lat1)*sin(lat2) + cos(lat1)*cos(lat2)*cos(long1 - long2)))*6371)::numeric(10,6), 3)) as dist,
		air1, air2, dist_air
	from c3)
select air1, air2, dist, dist_air,
	(dist_air - dist) as diff,
	case when (dist_air - dist) >= 0 then 'ok'
	else 'not ok'
	end
from c4

	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	