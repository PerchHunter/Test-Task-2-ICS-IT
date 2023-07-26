/*
	1. Должен быть комментарий в шапке объекта.
	Нужно писать "create or alter", чтобы повторное выполнение скрипта не приводило к возникновению ошибки.
	Если не ошибаюсь, если один параметр, то его можно не переносить на следующую строку
*/
create procedure syn.usp_ImportFileCustomerSeasonal
	@ID_Record int
as
set nocount on
begin
	-- 2. Все переменные должны задаваться в одном объявлении
	-- 3. Рекомендуется при объявлении типов не использовать длину поля max
	declare @RowCount int = (select count(*) from syn.SA_CustomerSeasonal)
	declare @ErrorMessage varchar(max)

	-- 4. Коммментарий должен быть на одном уровне с кодом, к которому он относится
-- Проверка на корректность загрузки
	if not exists (
	-- 5. Внутри скобок код должен быть смещён на один таб
	select 1
	-- 6. Не правильный алиас. Должен быть "imf". Не "if", т.к. это системное слово
	from syn.ImportFile as f
	where f.ID = @ID_Record
		and f.FlagLoaded = cast(1 as bit)
	)
	-- 7. if и else с begin/end должны быть на одном уровне
		begin
			set @ErrorMessage = 'Ошибка при загрузке файла, проверьте корректность данных'

			raiserror(@ErrorMessage, 3, 1)
			-- 8. Должна быть пустая строка перед "return"
			return
		end

	-- 9. CREATE TABLE ловеркейсом, должен быть пробел между скобкой и названием таблицы
	CREATE TABLE #ProcessedRows(ActionType varchar(255), ID int)
	
	--Чтение из слоя временных данных
	select
		cc.ID as ID_dbo_Customer
		,cst.ID as ID_CustomerSystemType
		,s.ID as ID_Season
		,cast(sa.DateBegin as date) as DateBegin
		,cast(sa.DateEnd as date) as DateEnd
		,cd.ID as ID_dbo_CustomerDistributor
		,cast(isnull(sa.FlagActive, 0) as bit) as FlagActive
	into #CustomerSeasonal
	-- 10. Пропущено "as". syn.SA_CustomerSeasonal as cs
	-- 11. Во всём этом запросе и запросе ниже по коду вместо алиаса "sa" должен быть алиас "cs"
	from syn.SA_CustomerSeasonal cs
		join dbo.Customer as cc on cc.UID_DS = sa.UID_DS_Customer
			and cc.ID_mapping_DataSource = 1
		join dbo.Season as s on s.Name = sa.Season
		join dbo.Customer as cd on cd.UID_DS = sa.UID_DS_CustomerDistributor
			and cd.ID_mapping_DataSource = 1
		-- 12. Сперва указываем поле присоединяемой таблицы
		join syn.CustomerSystemType as cst on sa.CustomerSystemType = cst.Name
	where try_cast(sa.DateBegin as date) is not null
		and try_cast(sa.DateEnd as date) is not null
		and try_cast(isnull(sa.FlagActive, 0) as bit) is not null

	-- Определяем некорректные записи
	-- Добавляем причину, по которой запись считается некорректной
	select
		sa.*
		,case
			-- 13. "then" везде должен быть перенесён на следующую строку и сдвинут на один таб
			when cc.ID is null then 'UID клиента отсутствует в справочнике "Клиент"'
			when cd.ID is null then 'UID дистрибьютора отсутствует в справочнике "Клиент"'
			when s.ID is null then 'Сезон отсутствует в справочнике "Сезон"'
			when cst.ID is null then 'Тип клиента в справочнике "Тип клиента"'
			when try_cast(sa.DateBegin as date) is null then 'Невозможно определить Дату начала'
			when try_cast(sa.DateEnd as date) is null then 'Невозможно определить Дату начала'
			when try_cast(isnull(sa.FlagActive, 0) as bit) is null then 'Невозможно определить Активность'
		end as Reason
	into #BadInsertedRows
	from syn.SA_CustomerSeasonal as cs
	-- 13. Все виды join пишутся с одним отступом. При сдвиге также нужно будет сдвинуть и "and'ы"
	left join dbo.Customer as cc on cc.UID_DS = sa.UID_DS_Customer
		and cc.ID_mapping_DataSource = 1
	-- 14. "and" не был перенесён на следующую строку
	left join dbo.Customer as cd on cd.UID_DS = sa.UID_DS_CustomerDistributor and cd.ID_mapping_DataSource = 1
	left join dbo.Season as s on s.Name = sa.Season
	left join syn.CustomerSystemType as cst on cst.Name = sa.CustomerSystemType
	where cc.ID is null
		or cd.ID is null
		or s.ID is null
		or cst.ID is null
		or try_cast(sa.DateBegin as date) is null
		or try_cast(sa.DateEnd as date) is null
		or try_cast(isnull(sa.FlagActive, 0) as bit) is null

-- 15. Две пустые строки перед "end" лишние
end
