DELIMITER //

CREATE OR REPLACE PROCEDURE bigdrop(IN p_tableschema VARCHAR(128),IN p_tablename VARCHAR(128),IN p_nibble INT,IN p_pause INT)
#  Drop big/huge tables in nibbles to avoid innodb buffer pool and galera locks
# p_tableschema :: Schema of the table  
# p_tablename   :: Table to clean in nibbles and drop
# p_nibble      :: Size in rows of each single nibble. 10k to 1M is a reasonable range depending on several factors.
# p_pause       :: Pause in seconds between deletes. It also depends on p_nibble. Leaves room for breathing and let anything locked to go ahead, especially important parameter for Galera. Range might be 1s-20s depending.

BEGIN
  SET @progress=0;
  SET @rowcountstm=CONCAT("SELECT @i:=TABLE_ROWS `Estimated rowcount` FROM information_schema.tables WHERE TABLE_NAME='",p_tablename,"' AND TABLE_SCHEMA='",p_tableschema,"'");
  PREPARE stmt0 FROM @rowcountstm;
  EXECUTE stmt0;
  DEALLOCATE PREPARE stmt0;
  SET @delstm = CONCAT('DELETE FROM ',p_tableschema,'.',p_tablename,' LIMIT ',p_nibble);
  PREPARE stmt1 FROM @delstm;
  SELECT CONCAT('',p_tablename) `Cleanup of table`, CONCAT('',p_nibble) `Nibble size in rows`, CONCAT('',p_pause) `Pause between nibbles (in seconds)`;
  # The above select will make sure the while loop enters
  WHILE ROW_COUNT()!=0 DO
      SET @progress=@progress+ROW_COUNT()+1;
      DO SLEEP(p_pause);
      SELECT (@progress/@i)*100 `%`;
      EXECUTE stmt1;
  END WHILE;
  DEALLOCATE PREPARE stmt1;
  SET @dropstm = CONCAT('DROP TABLE ',p_tablename);
  PREPARE stmt2 FROM @dropstm;
  EXECUTE stmt2;
  DEALLOCATE PREPARE stmt2;
END//

DELIMITER ;
