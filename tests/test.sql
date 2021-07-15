select name, json_extract(meta, '$.ApertureValue[0]') as aperture
from media;

---

select * from media;

---

select strftime('%Y-%m-%d', created) as created, strftime('%Y-%m-%d %H:%M:%S', modified) as modified from media;

---

delete from media where id = 3;