  
-- =============================================  
-- Author:  Alan Rosales  
-- Create date: 21/01/2020  
-- Description: Alta de Orden hasta estatus cobranza SSC  
  
/*   
 INS_ORDEN_SSC_SP   
 37585,  
 '
  [{"idPartida":727368,"partida":"CHRPAT19.0727368","noParte":"M.O.","cantidad":1,"descripcion":"MANO DE OBRA POR HORA","costo":189,"venta":189,"idEstatusPartida":1,"$$hashKey":"object:145550"}]
 '  
*/   
  
-- =============================================  
CREATE PROCEDURE [dbo].[INS_ORDEN_SSC_SP]  
 @idUnidad int,  
 @jsonPartidas varchar(max)  
as
begin  
 set language spanish  
 --declaramos variables y asignamos valores hardcode  
  
 begin try  
  
 --BEGIN TRANSACTION  
  
 declare   
  @idUsuario int = 2051        
  ,@idTaller int = 1375       
  ,@idTipoOrdenServicio int = 2     
  ,@idEstadoUnidad int = 1      
  ,@fechaCita NVARCHAR(max) = convert(varchar,getdate(),103) + ' ' + convert(varchar,getdate(),8)  
  ,@grua int = 0         
  ,@comentario varchar(max) = 'aut'     
  ,@idCentroTrabajo int = 0  
  ,@idOrdenMuestra int = 149012  
  --VARIABLES  
  ,@idZona int  
  ,@especialidades varchar(max)  
  ,@partidas varchar(max)  
  ,@idOrden int  
  ,@numeroOrden varchar(max)  
  ,@idCotizacion int  
  
  
 select @idZona = idZona from Unidades where idUnidad = @idUnidad  
  
 create table #partidas(  
  id int identity(1,1),  
  idPartida int,  
  idEspecialidad int,  
  costo float,  
  venta float,  
  cantidad float  
 )  
   
 DECLARE   
  @parent AS INT,  
  @idPartida_ int,  
  @idEspecialidad_ int,  
  @costo_ float,  
  @venta_ float,  
  @cantidad_ float  
   
   
  
 DECLARE _cursor CURSOR FOR   
 SELECT Object_ID FROM dbo.parseJSON(@jsonPartidas) WHERE Object_ID IS NOT NULL AND ValueType = 'object'  ORDER BY Object_ID  
 OPEN _cursor   
 FETCH NEXT FROM _cursor INTO @parent  
 WHILE @@FETCH_STATUS = 0   
 BEGIN  
  SELECT @idPartida_ = REPLACE(StringValue,'"','')  FROM dbo.parseJSON(@jsonPartidas) WHERE parent_ID = @parent AND NAME = 'idPartida' AND Object_ID IS NULL  
  SELECT @costo_ = REPLACE(StringValue,'"','')  FROM dbo.parseJSON(@jsonPartidas) WHERE parent_ID = @parent AND NAME = 'costo' AND Object_ID IS NULL  
  SELECT @venta_ = REPLACE(StringValue,'"','')  FROM dbo.parseJSON(@jsonPartidas) WHERE parent_ID = @parent AND NAME = 'venta' AND Object_ID IS NULL  
  SELECT @cantidad_ = REPLACE(StringValue,'"','')  FROM dbo.parseJSON(@jsonPartidas) WHERE parent_ID = @parent AND NAME = 'cantidad' AND Object_ID IS NULL  
  
  set @idEspecialidad_ = (select idEspecialidad from Partidas..Partida where idPartida = @idPartida_)  
  
  insert into #partidas values (@idPartida_, @idEspecialidad_,@costo_,@venta_,@cantidad_)  
  FETCH NEXT FROM _cursor INTO @parent  
 END  
 CLOSE _cursor   
 DEALLOCATE _cursor  
  
   
  
 SELECT  @especialidades = STUFF(( SELECT DISTINCT ',' + convert(varchar,idEspecialidad) + ','  
                FROM #partidas  
              FOR  
                XML PATH('')  
              ), 1, 1, '')  
  
 SELECT  @partidas = STUFF(( SELECT DISTINCT ',' + convert(varchar,idPartida)   
                FROM #partidas  
              FOR  
                XML PATH('')  
              ), 1, 1, '')  
  
  

 --CREAMOS LAS TABLAS TEMPORALES DE SALIDA DE SPS AUXILIARES  
  
 create table #orden(  
  respuesta int,  
  mensaje varchar(max),  
  idOrden int,  
  numeroOrden varchar(max)  
 )  
 create table #cotizacion(  
  idCotizacion int,  
  numeroCotizacion varchar(max),  
  mensaje varchar(max)  
 )  
  
 create table #cotizacionDetalle(  
  idCotizacionDetalle int,  
  mensaje varchar(max)  
 )  
  
 create table #cotizacionFinal(  
  idCotizacion int,  
  idOrden int,
  estatus int
 )  
  
 create table #salida(  
  var1 varchar(max),  
  var2 varchar(max)  
 )  
  
 declare @query varchar(max)  
  
 --1. CREAMOS ORDEN  
   print 'paso 1'
   print @idUnidad
print @idUsuario
print @idTipoOrdenServicio
print @idEstadoUnidad
print @grua
print @fechaCita
print @comentario
print @idZona
print 0
print @especialidades
print @idCentroTrabajo


 SET @query = 'EXEC [dbo].[INS_ORDEN_SERVICIO_SSC_SP] ' +  
  convert(varchar,@idUnidad)  
  +',' + convert(varchar,@idUsuario)  
  +',' + convert(varchar,@idTipoOrdenServicio)  
  +',' + convert(varchar,@idEstadoUnidad)  
  +',' + convert(varchar,@grua)  
  +',''' + @fechaCita + ''''  
  +',''' + convert(varchar(max),@comentario) + ''''  
  +',' + convert(varchar,@idZona)  
  +',' + convert(varchar,0)  
  +',''' + convert(varchar(MAX),@especialidades) + ''''  
  +',' + convert(varchar,@idCentroTrabajo)  
  
  PRINT 'EJECUTA ORDEN'
  PRINT @query
 insert into #orden  
 exec(@query)  
   
 --2. GUARDAMOS LA PREORDEN (ENCABEZADO)   
  print 'paso 2'
 SELECT @idOrden = idOrden, @numeroOrden = numeroOrden from #orden   
 set @query = 'EXEC INS_COTIZACION_NUEVA_SP ' +   
  convert(varchar,0)  
  +',' + convert(varchar,@idUsuario)  
  +',' + convert(varchar,5)  
  +',''' + convert(varchar(max),@numeroOrden) + ''''  
  +',' + convert(varchar,@idTipoOrdenServicio)  
  +',' + convert(varchar,0)  
  
 insert into #cotizacion  
 exec(@query)    

    SELECT @idCotizacion = idCotizacion from #cotizacion
   
 --3. INSERTAMOS DETALLE DE COTIZACION  
 print 'paso 3'
  
 declare @i int = 1  
  
 while @i<=(select count(1) from #partidas)  
 begin  
  select   
   @idPartida_ = idPartida,  
   @costo_ = costo,  
   @venta_ = venta,  
   @cantidad_ = cantidad  
  from #partidas where id = @i  
  
  set @query  = 'EXEC INS_COTIZACION_DETALLE_SP ' +  
   convert(varchar,@idCotizacion)   
   +',' + convert(varchar(max),@costo_)  
   +',' + convert(varchar(max),@cantidad_)  
   +',' + convert(varchar(max),@venta_)  
   +',' + convert(varchar(max),@idPartida_)  
   +',' + convert(varchar(max),1)  
  
  INSERT INTO #cotizacionDetalle  
  exec(@query)  
  set @i = @i+1  
 end  
  
 --4. GENERAR COTIZACION DESDE PREORDEN  
   
  print 'paso 4'
 set @query = 'EXEC INS_COTIZACION_PREORDEN_SP '   
  + convert(varchar,@idCotizacion)  
  + ',' + convert(varchar(max),@idUsuario)  
  + ',' + convert(varchar(max),@idTaller)  
  + ',''' + convert(varchar(max),@partidas) + ''''  
  + ',' + convert(varchar(max),@idZona)  
  + ',' + convert(varchar(max),@idTipoOrdenServicio)  

  print 'query que falla: ' + @query
  
 insert into #cotizacionFinal  
 exec(@query)  
  
 select   
  @idOrden = idOrden,   
  @idCotizacion = idCotizacion   
 from #cotizacionFinal  
  
 --5. INSERAMOS VALORES PARA COMPROBANTE DE RECEPCION  
  print 'paso 5'
 INSERT INTO ModuloComprobante  
 select   
  idCatalogoModuloComprobante,  
  @idOrden   
 from ModuloComprobante where idOrden=@idOrdenMuestra  
  
 --YA QUE INSERTAMOS LOS VALORES DESDE LA ORDEN MUESTRA OBTENEMOS EL DETALLE  
 insert into DetalleModuloComprobante  
 SELECT   
  det.accion,  
  det.idCatalogoDetalleModuloComprobante,  
  com2.idModuloComprobante,  
  det.descripcion  
 FROM ModuloComprobante com  
 inner join DetalleModuloComprobante det on com.idModuloComprobante = det.idModuloComprobante  
 inner join ModuloComprobante com2 on com2.idCatalogoModuloComprobante = com.idCatalogoModuloComprobante  
 where com.idOrden = @idOrdenMuestra and com2.idOrden = @idOrden  
 order by idCatalogoDetalleModuloComprobante   
  
 --6. AVANZAMOS LA ORDEN  
  PRINT 'PASO 6'
 set @query = 'EXEC UPD_ESTATUS_RECEPCION_SP '   
  + CONVERT(VARCHAR,@idUsuario)  
  + ',' + CONVERT(varchar,@idOrden)  
  
  INSERT INTO #salida(var1)  
  EXEC (@query)  
  
 --7. AVANZAMOS A APROBACION  
 PRINT 'PASO 7'
 set @query = 'exec UPD_ESTATUS_ORDEN_SERVICIO_SP '   
  +CONVERT(VARCHAR,@idOrden)  
  +',' + convert(varchar, @idUsuario)  
  
 insert into #salida  
 exec(@query)  
  
 --8. APOBAMOS LAS PARTIDAS  
  PRINT 'PASO 8'
 SET @i=1  
 while @i<=(select count(1) from #partidas)  
 begin  
  select   
   @idPartida_ = idPartida,  
   @costo_ = costo,  
   @venta_ = venta,  
   @cantidad_ = cantidad  
  from #partidas where id = @i  
    
  set @query = 'exec UPD_ESTATUS_APROBACION_PARTIDAS '  
   + convert(varchar,@idUsuario)  
   +',' + convert(varchar,@idCotizacion)  
   +',' + convert(varchar,@idPartida_)  
   +',' + convert(varchar,2)  
  insert into #salida(var1)  
  exec(@query)  
  
  set @i = @i+1  
 end  
  
 --9. ACTUALIZAMOS LA APROBACION DE LA COTIZACION 
 PRINT 'PASO 9' 
 set @query = 'exec UPD_ESTATUS_APROBACION_COTIZACION '   
  + convert(varchar,@idCotizacion)  
  + ',' + convert(varchar,@idUsuario)  
  
  insert into #salida(var1)  
  exec(@query)  
  
   
 --Salida hacia el front  
 select   
  '' Error,  
  idOrden,  
  numeroOrden,  
  idCotizacion  
    
 from #orden, #cotizacion  
  
 drop table #orden  
 drop table #cotizacion  
 drop table #partidas  
 drop table #cotizacionFinal  
 drop table #cotizacionDetalle  
 drop table #salida  
  
 end try  
 begin catch  
  select 'Error al insertar la Orden: ' +  ERROR_MESSAGE() + '' + convert(varchar,ERROR_LINE()) AS ERROR,0 idOrden,'' numeroOrden  
  --ROLLBACK TRANSACTION  
 end catch  
end



go

