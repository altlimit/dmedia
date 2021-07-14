select name, json_extract(meta, '$.ApertureValue[0]') as aperture
from media;

---

select * from media order by date desc;