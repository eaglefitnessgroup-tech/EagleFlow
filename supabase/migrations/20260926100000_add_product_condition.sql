alter table public.products
  add column condition text null,
  add constraint products_condition_check
    check (
      condition is null
      or condition in ('new', 'used', 'refurbished', 'display')
    );
