select name, json_extract(meta, '$.ApertureValue[0]') as aperture
from media;

---

select * from media LIMIT 10;

---

select * from migrations;

---

select * from user;

---

select strftime('%Y-%m-%d', NULL) as created, strftime('%Y-%m-%d %H:%M:%S', modified) as modified from media;

---

delete from media where id = 3;

---

update media set deleted = CURRENT_TIMESTAMP WHERE id IN (1,2);

---

select datetime(CURRENT_TIMESTAMP, 'localtime');