

PageClassRegistrar.add(
  'EventPage',
  :controller => 'event_page',
  :model => 'Event',
  :icon => 'date',
  :class_group => 'planning',
  :order => 120
)

#self.override_views = true
self.load_once = false

